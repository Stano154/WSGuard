package sk.webostudio.web_blocker

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Budík na koniec časových blokovaní: uprace skončené pravidlá (prejdú do stavu "Povolené")
 * a naplánuje ďalší budík. Upozornenia sa neposielajú.
 */
class TimerReceiver : BroadcastReceiver() {

    companion object {
        private const val REQUEST = 7001

        /** Naplánuje budík na najbližší koniec časového blokovania (alebo ho zruší). */
        fun scheduleNext(context: Context) {
            val alarm = context.getSystemService(AlarmManager::class.java) ?: return
            val intent = PendingIntent.getBroadcast(
                context, REQUEST,
                Intent(context, TimerReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val now = BlockStore.now(context)
            val next = BlockStore.timers(context).values.filter { it > now }.minOrNull()
            if (next == null) {
                alarm.cancel(intent)
            } else {
                // Budík sa riadi časom od zapnutia telefónu – posunutie hodín ho neurýchli.
                // Nepresný budík stačí (môže meškať pár minút) a nevyžaduje špeciálne povolenie.
                alarm.setAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    android.os.SystemClock.elapsedRealtime() + (next - now) + 1000,
                    intent,
                )
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        BlockStore.housekeeping(context)
        scheduleNext(context)
    }
}
