package sk.webostudio.web_blocker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.VpnService

/** Po reštarte telefónu znovu zapne VPN, ak bola zapnutá. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (BlockStore.isVpnEnabled(context) && VpnService.prepare(context) == null) {
            BlockerVpnService.start(context)
        }
    }
}
