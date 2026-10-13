package sk.webostudio.web_blocker

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.VpnService

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "sk.webostudio.web_blocker/blocker"
        private const val VPN_REQUEST = 4242
        private const val ADMIN_REQUEST = 4243
    }

    private var pendingVpnResult: MethodChannel.Result? = null
    private var pendingAdminResult: MethodChannel.Result? = null

    private val dpm get() = getSystemService(DevicePolicyManager::class.java)
    private fun adminActive() = dpm?.isAdminActive(GuardAdminReceiver.component(this)) == true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Ak bola VPN zapnutá, ale systém proces ukončil (napr. po aktualizácii), obnovíme ju.
        if (BlockStore.isVpnEnabled(this) && !BlockerVpnService.isRunning && VpnService.prepare(this) == null) {
            BlockerVpnService.start(this)
        }
        // Ochrana mohla byť vypnutá mimo aplikácie (napr. v núdzovom režime).
        if (BlockStore.isUninstallProtection(this) && !adminActive()) {
            BlockStore.setUninstallProtection(this, false)
        }
        TimerReceiver.scheduleNext(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getState" -> result.success(state())
                "setEntries" -> {
                    BlockStore.setEntries(this, call.argument<List<String>>("entries") ?: emptyList())
                    result.success(state())
                }
                "setApps" -> {
                    BlockStore.setApps(this, call.argument<List<String>>("apps") ?: emptyList())
                    result.success(state())
                }
                "setDisabled" -> {
                    call.argument<List<String>>("entries")?.let { BlockStore.setDisabledEntries(this, it) }
                    call.argument<List<String>>("apps")?.let { BlockStore.setDisabledApps(this, it) }
                    call.argument<List<String>>("lists")?.let { BlockStore.setDisabledLists(this, it) }
                    result.success(state())
                }
                "setLists" -> {
                    val raw = call.argument<List<Map<String, Any?>>>("lists") ?: emptyList()
                    BlockStore.setLists(this, raw.map { m ->
                        @Suppress("UNCHECKED_CAST")
                        BlockStore.BlockList(
                            id = m["id"] as String,
                            name = (m["name"] as? String).orEmpty(),
                            emoji = (m["emoji"] as? String) ?: "📋",
                            sites = (m["sites"] as? List<String>).orEmpty(),
                            apps = (m["apps"] as? List<String>).orEmpty(),
                        )
                    })
                    result.success(state())
                }
                "setTimer" -> {
                    val key = call.argument<String>("key")!!
                    // Aplikácia posiela čas telefónu – prepočítame ho na dôveryhodný čas.
                    val until = (call.argument<Number>("until"))!!.toLong() - BlockStore.skew(this)
                    BlockStore.setTimer(this, key, until)
                    TimerReceiver.scheduleNext(this)
                    result.success(state())
                }
                "cancelTimer" -> {
                    val ok = BlockStore.cancelTimer(this, call.argument<String>("key")!!)
                    TimerReceiver.scheduleNext(this)
                    result.success(mapOf("ok" to ok, "state" to state()))
                }
                "pause" -> {
                    val r = BlockStore.pause(this, call.argument<String>("key")!!)
                    result.success(mapOf("ok" to r.ok, "reason" to r.reason, "state" to state()))
                }
                "getSettings" -> result.success(
                    BlockStore.settings(this) + ("language" to BlockStore.language(this))
                )
                "setSetting" -> {
                    val ok = BlockStore.setSetting(this, call.argument<String>("key")!!, call.argument<String>("value"))
                    result.success(ok)
                }
                "getInstalledApps" -> Thread {
                    val apps = installedApps()
                    runOnUiThread { result.success(apps) }
                }.start()
                "startVpn" -> startVpn(result)
                "stopVpn" -> {
                    if (BlockStore.isLocked(this)) return@setMethodCallHandler result.error("locked", null, null)
                    BlockStore.setVpnEnabled(this, false)
                    BlockerVpnService.stop(this)
                    result.success(null)
                }
                "setAccessibility" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    if (!enabled && BlockStore.isLocked(this)) {
                        return@setMethodCallHandler result.error("locked", null, null)
                    }
                    BlockStore.setAccessibilityEnabled(this, enabled)
                    result.success(state())
                }
                "openAccessibilitySettings" -> {
                    BlockStore.guardBypassUntil = System.currentTimeMillis() + 60_000
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "setUninstallProtection" -> setUninstallProtection(call.argument<Boolean>("enabled") == true, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Návrat do WSGuard – výnimka pre strážcu nastavení už nie je potrebná.
        BlockStore.guardBypassUntil = 0
    }

    private fun state(): Map<String, Any> {
        // Časy sú uložené v dôveryhodnom čase; aplikácia počíta s časom telefónu.
        val skew = BlockStore.skew(this)
        val timers = BlockStore.timers(this)
        val lockedUntil = BlockStore.lockedUntil(this)
        return mapOf(
            "entries" to BlockStore.entries(this),
            "apps" to BlockStore.apps(this).toList(),
            "disabledEntries" to BlockStore.disabledEntries(this).toList(),
            "disabledApps" to BlockStore.disabledApps(this).toList(),
            "disabledLists" to BlockStore.disabledLists(this).toList(),
            "lists" to BlockStore.lists(this).map { it.toMap() },
            "timers" to timers.mapValues { it.value + skew },
            "pauses" to BlockStore.pauses(this).mapValues { it.value + skew },
            "cancelUntil" to BlockStore.cancelDeadlines(this).mapValues { it.value + skew },
            "pauseUsed" to timers.keys.associateWith { BlockStore.pauseUsedToday(this, it) },
            "unblockMinutes" to BlockStore.unblockMinutes(this),
            "unblockPerDay" to BlockStore.unblockPerDay(this),
            "lockedUntil" to if (lockedUntil > 0) lockedUntil + skew else 0L,
            "uninstallProtection" to (BlockStore.isUninstallProtection(this) && adminActive()),
            "vpnRunning" to BlockerVpnService.isRunning,
            "accessibilityEnabled" to BlockStore.isAccessibilityEnabled(this),
            "accessibilityServiceOn" to BlockerAccessibilityService.isEnabledInSettings(this),
            "blockedCount" to BlockStore.blockedCount(this),
            "now" to System.currentTimeMillis(),
        )
    }

    private fun setUninstallProtection(enabled: Boolean, result: MethodChannel.Result) {
        if (enabled) {
            if (adminActive()) {
                BlockStore.setUninstallProtection(this, true)
                return result.success(true)
            }
            // Systémová obrazovka "Aktivovať správcu zariadenia" – strážca ju nesmie zablokovať.
            BlockStore.guardBypassUntil = System.currentTimeMillis() + 120_000
            pendingAdminResult = result
            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, GuardAdminReceiver.component(this))
                .putExtra(
                    DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                    if (BlockStore.language(this) == "en") {
                        "WSGuard uses this only to prevent uninstalling. You can turn it off in WSGuard settings with your password."
                    } else {
                        "WSGuard to používa iba na zabránenie odinštalovaniu. Vypnúť to môžeš v nastaveniach WSGuard heslom."
                    },
                )
            startActivityForResult(intent, ADMIN_REQUEST)
        } else {
            if (BlockStore.isLocked(this)) return result.error("locked", null, null)
            if (adminActive()) dpm?.removeActiveAdmin(GuardAdminReceiver.component(this))
            BlockStore.setUninstallProtection(this, false)
            result.success(false)
        }
    }

    /** Aplikácie, ktoré sa dajú spustiť z plochy: balík, názov a ikona (PNG). */
    private fun installedApps(): List<Map<String, Any>> {
        val pm = packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val size = (48 * resources.displayMetrics.density).toInt()
        return pm.queryIntentActivities(launcher, 0)
            .map { it.activityInfo.applicationInfo }
            .distinctBy { it.packageName }
            .filter { it.packageName != packageName }
            .mapNotNull { info ->
                try {
                    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
                    val icon = pm.getApplicationIcon(info)
                    icon.setBounds(0, 0, size, size)
                    icon.draw(Canvas(bitmap))
                    val png = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, png)
                    mapOf(
                        "package" to info.packageName,
                        "label" to pm.getApplicationLabel(info).toString(),
                        "icon" to png.toByteArray(),
                    )
                } catch (_: Exception) {
                    null
                }
            }
            .sortedBy { (it["label"] as String).lowercase() }
    }

    private fun startVpn(result: MethodChannel.Result) {
        val consent = VpnService.prepare(this)
        if (consent == null) {
            BlockerVpnService.start(this)
            result.success(true)
        } else {
            pendingVpnResult = result
            startActivityForResult(consent, VPN_REQUEST)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            VPN_REQUEST -> {
                val granted = resultCode == Activity.RESULT_OK
                if (granted) BlockerVpnService.start(this)
                pendingVpnResult?.success(granted)
                pendingVpnResult = null
            }
            ADMIN_REQUEST -> {
                BlockStore.guardBypassUntil = 0
                val active = adminActive()
                BlockStore.setUninstallProtection(this, active)
                pendingAdminResult?.success(active)
                pendingAdminResult = null
            }
        }
    }
}
