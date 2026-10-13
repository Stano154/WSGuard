package sk.webostudio.web_blocker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Systém oznámi zmenu dátumu/času (napr. ručné nastavenie hodín).
 * Posun si hneď zapamätáme, aby sa ním nedalo skrátiť časové blokovanie.
 */
class ClockReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        BlockStore.checkClock(context)
        TimerReceiver.scheduleNext(context)
    }
}
