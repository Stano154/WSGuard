package sk.webostudio.web_blocker

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Budík na koniec časových blokovaní: uprace skončené pravidlá (prejdú do stavu "Povolené"),
 * pošle upozornenie a naplánuje ďalší budík.
 */
class TimerReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL = "timers"
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

        fun displayName(context: Context, key: String): String {
            val id = key.substringAfter(':')
            return when (key.substringBefore(':')) {
                "app" -> try {
                    val pm = context.packageManager
                    pm.getApplicationLabel(pm.getApplicationInfo(id, 0)).toString()
                } catch (_: Exception) {
                    id
                }
                "list" -> BlockStore.lists(context).firstOrNull { it.id == id }?.name ?: id
                else -> id
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val expired = BlockStore.housekeeping(context)
        if (expired.isNotEmpty()) notify(context, expired)
        scheduleNext(context)
    }

    private fun notify(context: Context, expired: List<String>) {
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        val en = BlockStore.language(context) == "en"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    if (en) "Timed blocking" else "Časové blokovanie",
                    NotificationManager.IMPORTANCE_DEFAULT,
                )
            )
        }
        val names = expired.map { displayName(context, it) }.joinToString(", ")
        val open = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE,
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, CHANNEL)
        } else {
            android.app.Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(if (en) "Timed blocking ended" else "Časové blokovanie skončilo")
            .setContentText(if (en) "$names is unblocked again" else "$names je znova odblokované")
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(expired.hashCode(), notification)
        } catch (_: SecurityException) {
            // Používateľ nepovolil upozornenia – nevadí, blokovanie aj tak skončilo.
        }
    }
}
