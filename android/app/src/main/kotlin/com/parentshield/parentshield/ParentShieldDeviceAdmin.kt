package com.parentshield.parentshield

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class ParentShieldDeviceAdmin : DeviceAdminReceiver() {

    companion object {
        private const val TAG = "ParentShieldAdmin"
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d(TAG, "Device Admin enabled")
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        return "Disabling ParentShield will remove parental protections. Your parent will be notified."
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d(TAG, "Device Admin disabled — parent should be notified")
    }
}
