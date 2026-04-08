package me.vinch.pocketrelay

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object TurnCompletionNotification {
    fun show(context: Context, title: String, body: String?) {
        createNotificationChannelIfNeeded(context)
        NotificationManagerCompat.from(context).notify(
            NOTIFICATION_ID,
            buildNotification(context, title, body),
        )
    }

    fun clear(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    private fun buildNotification(
        context: Context,
        title: String,
        body: String?,
    ) = NotificationCompat.Builder(context, CHANNEL_ID)
        .setContentTitle(title)
        .apply {
            val resolvedBody = body?.trim().orEmpty()
            if (resolvedBody.isNotEmpty()) {
                setContentText(resolvedBody)
                setStyle(NotificationCompat.BigTextStyle().bigText(resolvedBody))
            }
        }
        .setSmallIcon(R.drawable.ic_turn_completion_notification)
        .setContentIntent(launchContentIntent(context))
        .setAutoCancel(true)
        .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
        .setCategory(NotificationCompat.CATEGORY_STATUS)
        .setPriority(NotificationCompat.PRIORITY_DEFAULT)
        .build()

    private fun launchContentIntent(context: Context): PendingIntent? {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(
            context.packageName,
        )?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        } ?: return null

        return PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createNotificationChannelIfNeeded(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = context.getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.turn_completion_notification_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(
                R.string.turn_completion_notification_channel_description,
            )
        }
        manager.createNotificationChannel(channel)
    }

    private const val CHANNEL_ID = "pocket_relay_turn_completion"
    private const val NOTIFICATION_ID = 1002
}
