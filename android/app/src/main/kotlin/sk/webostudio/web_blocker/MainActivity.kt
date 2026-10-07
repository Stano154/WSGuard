package sk.webostudio.web_blocker

import android.app.Activity
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
    }

    private var pendingVpnResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Ak bola VPN zapnutá, ale systém proces ukončil (napr. po aktualizácii), obnovíme ju.
        if (BlockStore.isVpnEnabled(this) && !BlockerVpnService.isRunning && VpnService.prepare(this) == null) {
            BlockerVpnService.start(this)
        }
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
                    BlockStore.setDisabledEntries(this, call.argument<List<String>>("entries") ?: emptyList())
                    BlockStore.setDisabledApps(this, call.argument<List<String>>("apps") ?: emptyList())
                    result.success(state())
                }
                "getSettings" -> result.success(
                    BlockStore.settings(this) + ("language" to BlockStore.language(this))
                )
                "setSetting" -> {
                    BlockStore.setSetting(this, call.argument<String>("key")!!, call.argument<String>("value"))
                    result.success(null)
                }
                "getInstalledApps" -> Thread {
                    val apps = installedApps()
                    runOnUiThread { result.success(apps) }
                }.start()
                "startVpn" -> startVpn(result)
                "stopVpn" -> {
                    BlockStore.setVpnEnabled(this, false)
                    BlockerVpnService.stop(this)
                    result.success(null)
                }
                "setAccessibility" -> {
                    BlockStore.setAccessibilityEnabled(this, call.argument<Boolean>("enabled") == true)
                    result.success(state())
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun state(): Map<String, Any> = mapOf(
        "entries" to BlockStore.entries(this),
        "apps" to BlockStore.apps(this).toList(),
        "disabledEntries" to BlockStore.disabledEntries(this).toList(),
        "disabledApps" to BlockStore.disabledApps(this).toList(),
        "vpnRunning" to BlockerVpnService.isRunning,
        "accessibilityEnabled" to BlockStore.isAccessibilityEnabled(this),
        "accessibilityServiceOn" to BlockerAccessibilityService.isEnabledInSettings(this),
        "blockedCount" to BlockStore.blockedCount(this),
    )

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
        if (requestCode != VPN_REQUEST) return
        val granted = resultCode == Activity.RESULT_OK
        if (granted) BlockerVpnService.start(this)
        pendingVpnResult?.success(granted)
        pendingVpnResult = null
    }
}
