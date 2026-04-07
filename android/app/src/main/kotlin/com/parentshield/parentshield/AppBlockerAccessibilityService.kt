package com.parentshield.parentshield

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import java.util.Timer
import java.util.TimerTask

class AppBlockerAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AppBlockerService"
        const val PREFS_NAME = "parentshield_blocker"
        const val KEY_BLOCKED_PACKAGES = "blocked_packages"
        const val KEY_SERVICE_ENABLED = "service_enabled"
        const val KEY_DEVICE_ID = "device_id"
        const val KEY_CHILD_MODE_ACTIVE = "child_mode_active"
        private const val NOTIFICATION_CHANNEL_ID = "parentshield_blocker_channel"
        private const val NOTIFICATION_ID = 9999

        var instance: AppBlockerAccessibilityService? = null
            private set
    }

    private lateinit var prefs: SharedPreferences
    private var blockedPackages: Set<String> = emptySet()
    private var lastBlockedPackage: String? = null
    private var lastBlockTime: Long = 0
    private var pollingTimer: Timer? = null
    private var isChildModeActive: Boolean = false

    // Settings package names across OEMs
    private val settingsPackages = setOf(
        "com.android.settings",
        "com.samsung.android.app.settings",
        "com.miui.securitycenter",
        "com.miui.settings",
        "com.coloros.settings",
        "com.oppo.settings",
        "com.realme.settings",
        "com.vivo.settings",
        "com.nothing.settings",
        "com.oneplus.settings",
        "com.huawei.systemmanager",
        "com.android.providers.settings",
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        loadBlockedPackages()
        isChildModeActive = prefs.getBoolean(KEY_CHILD_MODE_ACTIVE, false)

        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.DEFAULT or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 50
        }
        serviceInfo = info

        // Show persistent notification to prevent system from killing the service
        createNotificationChannel()
        showPersistentNotification()

        // Start polling as backup detection method
        startPolling()

        Log.d(TAG, "Service connected. Blocked: $blockedPackages, ChildMode: $isChildModeActive")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return

        // Skip non-app events
        if (event.className?.toString()?.contains("PopupWindow") == true ||
            event.className?.toString()?.contains("Toast") == true) {
            return
        }

        checkAndBlockApp(packageName)
    }

    private fun checkAndBlockApp(packageName: String) {
        // Reload state
        loadBlockedPackages()
        isChildModeActive = prefs.getBoolean(KEY_CHILD_MODE_ACTIVE, false)

        if (!isServiceEnabled()) return

        // In child mode, block Settings app access
        if (isChildModeActive && settingsPackages.contains(packageName)) {
            val now = System.currentTimeMillis()
            if (packageName == lastBlockedPackage && now - lastBlockTime < 1500) return
            lastBlockedPackage = packageName
            lastBlockTime = now

            Log.d(TAG, "BLOCKING Settings access: $packageName (child mode)")
            launchBlockedScreen(packageName, "Settings access is restricted by your parent")
            return
        }

        // Don't block system essentials
        if (shouldSkipPackage(packageName)) return

        if (blockedPackages.contains(packageName)) {
            val now = System.currentTimeMillis()
            if (packageName == lastBlockedPackage && now - lastBlockTime < 1500) return
            lastBlockedPackage = packageName
            lastBlockTime = now

            Log.d(TAG, "BLOCKING app: $packageName")
            launchBlockedScreen(packageName, null)
        }
    }

    private fun shouldSkipPackage(packageName: String): Boolean {
        return packageName == this.packageName ||
                packageName == "com.android.systemui" ||
                packageName == "com.android.launcher" ||
                packageName == "com.android.launcher3" ||
                packageName == "com.google.android.apps.nexuslauncher" ||
                packageName == "com.sec.android.app.launcher" ||
                packageName == "com.huawei.android.launcher" ||
                packageName == "com.miui.home" ||
                packageName == "com.oppo.launcher" ||
                packageName == "com.realme.launcher" ||
                packageName == "com.vivo.launcher" ||
                packageName == "com.nothing.launcher" ||
                packageName == "android" ||
                packageName == "com.android.permissioncontroller" ||
                packageName == "com.google.android.inputmethod.latin" ||
                packageName == "com.samsung.android.honeyboard" ||
                packageName.contains("keyboard") ||
                packageName.contains("inputmethod") ||
                packageName.startsWith("com.android.packageinstaller")
    }

    private fun startPolling() {
        pollingTimer?.cancel()
        pollingTimer = Timer()
        pollingTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                try {
                    if (!isServiceEnabled()) return
                    loadBlockedPackages()
                    if (blockedPackages.isEmpty() && !isChildModeActive) return

                    val foregroundPackage = getForegroundPackage()
                    if (foregroundPackage != null) {
                        checkAndBlockApp(foregroundPackage)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Polling error: ${e.message}")
                }
            }
        }, 2000, 1000)
    }

    private fun getForegroundPackage(): String? {
        try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
                ?: return null

            val endTime = System.currentTimeMillis()
            val beginTime = endTime - 5000

            val usageStats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY, beginTime, endTime
            )

            if (usageStats.isNullOrEmpty()) return null

            var recentApp: String? = null
            var recentTime: Long = 0

            for (stat in usageStats) {
                if (stat.lastTimeUsed > recentTime) {
                    recentTime = stat.lastTimeUsed
                    recentApp = stat.packageName
                }
            }

            return recentApp
        } catch (e: Exception) {
            return null
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service interrupted")
    }

    override fun onDestroy() {
        // If child mode is active and service is being destroyed, relaunch the app
        val wasChildMode = prefs.getBoolean(KEY_CHILD_MODE_ACTIVE, false)

        instance = null
        pollingTimer?.cancel()
        pollingTimer = null

        if (wasChildMode) {
            Log.d(TAG, "Service destroyed while child mode active — relaunching app")
            try {
                // Show a high-priority notification
                showServiceDisabledNotification()

                // Relaunch the main activity
                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra("force_accessibility_prompt", true)
                }
                startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to relaunch after service destroy: ${e.message}")
            }
        }

        super.onDestroy()
    }

    private fun launchBlockedScreen(packageName: String, customMessage: String?) {
        val intent = Intent(this, BlockedAppActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("blocked_package", packageName)
            putExtra("app_name", getAppLabel(packageName))
            if (customMessage != null) {
                putExtra("custom_message", customMessage)
            }
        }
        startActivity(intent)
    }

    private fun getAppLabel(packageName: String): String {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }

    private fun loadBlockedPackages() {
        val packagesStr = prefs.getString(KEY_BLOCKED_PACKAGES, "") ?: ""
        blockedPackages = if (packagesStr.isNotEmpty()) {
            packagesStr.split(",").filter { it.isNotBlank() }.toSet()
        } else {
            emptySet()
        }
    }

    private fun isServiceEnabled(): Boolean {
        return prefs.getBoolean(KEY_SERVICE_ENABLED, false)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "ParentShield Protection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps ParentShield app blocking active"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun showPersistentNotification() {
        try {
            val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
                    .setContentTitle("ParentShield Active")
                    .setContentText("App blocking is protecting this device")
                    .setSmallIcon(android.R.drawable.ic_lock_lock)
                    .setOngoing(true)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
                    .setContentTitle("ParentShield Active")
                    .setContentText("App blocking is protecting this device")
                    .setSmallIcon(android.R.drawable.ic_lock_lock)
                    .setOngoing(true)
                    .build()
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show notification: ${e.message}")
        }
    }

    private fun showServiceDisabledNotification() {
        try {
            createNotificationChannel()
            val channelId = "parentshield_alert_channel"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "ParentShield Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Critical alerts when protection is disabled"
                }
                val nm = getSystemService(NotificationManager::class.java)
                nm?.createNotificationChannel(channel)
            }

            val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, channelId)
                    .setContentTitle("ParentShield Protection Disabled!")
                    .setContentText("App blocking was turned off. Tap to re-enable.")
                    .setSmallIcon(android.R.drawable.ic_dialog_alert)
                    .setAutoCancel(true)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
                    .setContentTitle("ParentShield Protection Disabled!")
                    .setContentText("App blocking was turned off. Tap to re-enable.")
                    .setSmallIcon(android.R.drawable.ic_dialog_alert)
                    .setAutoCancel(true)
                    .build()
            }

            val nm = getSystemService(NotificationManager::class.java)
            nm?.notify(NOTIFICATION_ID + 1, notification)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show alert notification: ${e.message}")
        }
    }

    // Public methods called from Flutter via MethodChannel

    fun updateBlockedPackages(packages: List<String>) {
        val packagesStr = packages.joinToString(",")
        prefs.edit().putString(KEY_BLOCKED_PACKAGES, packagesStr).apply()
        blockedPackages = packages.toSet()
        Log.d(TAG, "Updated blocked packages: $blockedPackages")
    }

    fun setEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_SERVICE_ENABLED, enabled).apply()
        Log.d(TAG, "Service enabled: $enabled")
    }

    fun setChildMode(active: Boolean) {
        prefs.edit().putBoolean(KEY_CHILD_MODE_ACTIVE, active).apply()
        isChildModeActive = active
        Log.d(TAG, "Child mode active: $active")
    }

    fun isBlockerEnabled(): Boolean {
        return isServiceEnabled()
    }
}
