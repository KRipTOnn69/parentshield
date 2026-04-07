package com.parentshield.parentshield

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Device booted - Accessibility Service will auto-restart if enabled in settings")
            // The Accessibility Service automatically restarts on boot
            // if the user has enabled it in Android Settings.
            // No manual restart needed.
        }
    }
}
