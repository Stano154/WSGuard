package sk.webostudio.web_blocker

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Blokuje aplikácie (podľa balíka v popredí) a stránky (podľa adresného riadku
 * podporovaných prehliadačov). Pri zablokovaní odíde z aplikácie/stránky
 * a zobrazí obrazovku s upozornením.
 */
class BlockerAccessibilityService : AccessibilityService() {

    companion object {
        /** Balík prehliadača -> ID políčka s adresou. */
        private val URL_BAR_IDS = mapOf(
            "com.android.chrome" to listOf("url_bar"),
            "com.chrome.beta" to listOf("url_bar"),
            "com.chrome.dev" to listOf("url_bar"),
            "com.brave.browser" to listOf("url_bar"),
            "com.microsoft.emmx" to listOf("url_bar"),
            "com.vivaldi.browser" to listOf("url_bar"),
            "com.kiwibrowser.browser" to listOf("url_bar"),
            "org.mozilla.firefox" to listOf("mozac_browser_toolbar_url_view", "url_bar_title"),
            "org.mozilla.firefox_beta" to listOf("mozac_browser_toolbar_url_view"),
            "org.mozilla.focus" to listOf("mozac_browser_toolbar_url_view", "display_url"),
            "com.sec.android.app.sbrowser" to listOf("location_bar_edit_text", "custom_tab_toolbar_url_bar_text"),
            "com.opera.browser" to listOf("url_field"),
            "com.opera.mini.native" to listOf("url_field"),
            "com.duckduckgo.mobile.android" to listOf("omnibarTextInput"),
            "com.mi.globalbrowser" to listOf("url"),
        )

        fun isEnabledInSettings(context: Context): Boolean {
            val expected = ComponentName(context, BlockerAccessibilityService::class.java).flattenToString()
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            return enabled.split(':').any { it.equals(expected, ignoreCase = true) }
        }
    }

    private var lastBlockedUrl: String? = null
    private var lastBlockedAt = 0L

    /** Krátka pauza po zablokovaní, aby sa jedno otvorenie nespracovalo viackrát. */
    private var pausedUntil = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !BlockStore.isAccessibilityEnabled(this)) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) return
        val now = System.currentTimeMillis()
        if (now < pausedUntil) return

        // 1) Zablokovaná aplikácia – stačí, že je v popredí.
        if (BlockStore.isAppBlocked(this, pkg)) {
            val foreground = rootInActiveWindow?.packageName?.toString()
            if (foreground == null || foreground == pkg) blockApp(pkg, now)
            return
        }

        // 2) Zablokovaná stránka v prehliadači.
        val ids = URL_BAR_IDS[pkg] ?: return
        val root = rootInActiveWindow ?: return
        val url = findUrl(root, pkg, ids) ?: return
        if (!BlockStore.isUrlBlocked(this, url)) return

        // Ochrana pred opakovaným spustením pri tej istej udalosti.
        if (url == lastBlockedUrl && now - lastBlockedAt < 3000) return
        lastBlockedUrl = url
        lastBlockedAt = now

        BlockStore.incrementBlocked(this)
        // Najprv prehliadač odíde zo stránky, až potom ukážeme upozornenie –
        // inak by systémové "Späť" zavrelo hneď aj obrazovku s upozornením.
        performGlobalAction(GLOBAL_ACTION_BACK)
        showBlocked(BlockedActivity.KIND_SITE, BlockStore.normalize(url) ?: url)
    }

    private fun blockApp(pkg: String, now: Long) {
        pausedUntil = now + 1000
        BlockStore.incrementBlocked(this)
        performGlobalAction(GLOBAL_ACTION_HOME)
        val label = try {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
        } catch (_: Exception) {
            pkg
        }
        showBlocked(BlockedActivity.KIND_APP, label)
    }

    private fun showBlocked(kind: String, name: String) {
        handler.postDelayed({
            startActivity(
                Intent(this, BlockedActivity::class.java)
                    .putExtra(BlockedActivity.EXTRA_KIND, kind)
                    .putExtra(BlockedActivity.EXTRA_URL, name)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            )
        }, 400)
    }

    private val handler = Handler(Looper.getMainLooper())

    private fun findUrl(root: AccessibilityNodeInfo, pkg: String, ids: List<String>): String? {
        for (id in ids) {
            val nodes = root.findAccessibilityNodeInfosByViewId("$pkg:id/$id")
            for (node in nodes) {
                // Kým používateľ píše do adresného riadku, neblokujeme.
                if (node.isFocused) continue
                val text = node.text?.toString()?.trim()
                if (!text.isNullOrEmpty() && text.contains('.') && !text.contains(' ')) return text
            }
        }
        return null
    }

    override fun onInterrupt() {}
}
