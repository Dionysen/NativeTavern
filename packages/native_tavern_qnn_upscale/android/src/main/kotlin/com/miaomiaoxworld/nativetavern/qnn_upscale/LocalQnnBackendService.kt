package com.miaomiaoxworld.nativetavern.qnn_upscale

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Foreground notification while a Local QNN generation model is loaded in memory.
 * Process lifecycle is owned by [NativeTavernQnnUpscalePlugin].
 */
class LocalQnnBackendService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val modelName = intent?.getStringExtra(EXTRA_MODEL_NAME) ?: "Local model"
        ensureChannel()
        val notification = buildNotification(modelName)
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            @Suppress("DEPRECATION")
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= 24) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Local image generation",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows while a local generation model is loaded"
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(modelName: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Local model loaded")
            .setContentText(modelName)
            .setSmallIcon(android.R.drawable.ic_menu_gallery)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "local_qnn_backend"
        private const val NOTIFICATION_ID = 48081
        const val EXTRA_MODEL_NAME = "model_name"

        fun start(context: Context, modelName: String) {
            val intent = Intent(context, LocalQnnBackendService::class.java).apply {
                putExtra(EXTRA_MODEL_NAME, modelName)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, LocalQnnBackendService::class.java))
        }
    }
}
