package dev.luzhire.luzhire

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Channel used by /api/notify/dispatch (android.notification.channelId).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "luzhire_updates",
                "LuzHire updates",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Applications, interviews, offers and team updates" }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
