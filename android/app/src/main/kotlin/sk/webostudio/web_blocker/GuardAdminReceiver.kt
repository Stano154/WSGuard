package sk.webostudio.web_blocker

import android.app.admin.DeviceAdminReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * Správca zariadenia – kým je aktívny, Android nedovolí WSGuard odinštalovať.
 * Nepoužíva žiadne právomoci (nemaže dáta, nezamyká telefón), slúži iba ako ochrana.
 */
class GuardAdminReceiver : DeviceAdminReceiver() {

    companion object {
        fun component(context: Context) = ComponentName(context, GuardAdminReceiver::class.java)
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence =
        if (BlockStore.language(context) == "en") {
            "This turns off WSGuard's uninstall protection. Blocked apps and sites may become accessible."
        } else {
            "Týmto vypneš ochranu WSGuard proti odinštalovaniu. Blokované aplikácie a stránky môžu byť dostupné."
        }

    override fun onDisabled(context: Context, intent: Intent) {
        // Napr. vypnuté v núdzovom režime – zosúladíme stav v aplikácii.
        BlockStore.setUninstallProtection(context, false)
    }
}
