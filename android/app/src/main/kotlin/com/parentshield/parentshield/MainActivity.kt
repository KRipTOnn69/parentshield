package com.parentshield.parentshield

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.parentshield/app_blocker"
        private const val DEVICE_ADMIN_REQUEST_CODE = 1234
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    val apps = getInstalledApps()
                    result.success(apps)
                }

                "isAccessibilityServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }

                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }

                "updateBlockedApps" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    updateBlockedApps(packages)
                    result.success(true)
                }

                "setBlockerEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    setBlockerEnabled(enabled)
                    result.success(true)
                }

                "isBlockerEnabled" -> {
                    val prefs = getSharedPreferences(
                        AppBlockerAccessibilityService.PREFS_NAME,
                        Context.MODE_PRIVATE
                    )
                    result.success(
                        prefs.getBoolean(AppBlockerAccessibilityService.KEY_SERVICE_ENABLED, false)
                    )
                }

                "getBlockedApps" -> {
                    val prefs = getSharedPreferences(
                        AppBlockerAccessibilityService.PREFS_NAME,
                        Context.MODE_PRIVATE
                    )
                    val packagesStr = prefs.getString(
                        AppBlockerAccessibilityService.KEY_BLOCKED_PACKAGES, ""
                    ) ?: ""
                    val packages = if (packagesStr.isNotEmpty()) {
                        packagesStr.split(",")
                    } else {
                        emptyList()
                    }
                    result.success(packages)
                }

                "setChildModeActive" -> {
                    val active = call.argument<Boolean>("active") ?: false
                    setChildModeActive(active)
                    result.success(true)
                }

                "requestDeviceAdmin" -> {
                    requestDeviceAdmin()
                    result.success(true)
                }

                "isDeviceAdminActive" -> {
                    result.success(isDeviceAdminActive())
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        val apps = mutableListOf<Map<String, Any>>()

        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        for (appInfo in packages) {
            // Skip system apps that aren't launchable
            if (appInfo.flags and ApplicationInfo.FLAG_SYSTEM != 0) {
                // Only include system apps that have a launcher icon
                if (pm.getLaunchIntentForPackage(appInfo.packageName) == null) {
                    continue
                }
            }

            // Skip our own app
            if (appInfo.packageName == packageName) continue

            val appName = pm.getApplicationLabel(appInfo).toString()
            val category = getCategoryName(appInfo.category)

            apps.add(
                mapOf(
                    "packageName" to appInfo.packageName,
                    "appName" to appName,
                    "category" to category,
                    "isSystemApp" to (appInfo.flags and ApplicationInfo.FLAG_SYSTEM != 0)
                )
            )
        }

        // Sort by app name
        apps.sortBy { (it["appName"] as String).lowercase() }

        return apps
    }

    private fun getCategoryName(category: Int): String {
        return when (category) {
            ApplicationInfo.CATEGORY_GAME -> "Games"
            ApplicationInfo.CATEGORY_AUDIO -> "Audio"
            ApplicationInfo.CATEGORY_VIDEO -> "Video"
            ApplicationInfo.CATEGORY_IMAGE -> "Photo"
            ApplicationInfo.CATEGORY_SOCIAL -> "Social Media"
            ApplicationInfo.CATEGORY_NEWS -> "News"
            ApplicationInfo.CATEGORY_MAPS -> "Maps"
            ApplicationInfo.CATEGORY_PRODUCTIVITY -> "Productivity"
            else -> "Other"
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(
            AccessibilityServiceInfo.FEEDBACK_ALL_MASK
        )

        for (service in enabledServices) {
            val serviceId = service.resolveInfo.serviceInfo
            if (serviceId.packageName == packageName &&
                serviceId.name == AppBlockerAccessibilityService::class.java.name
            ) {
                return true
            }
        }
        return false
    }

    private fun updateBlockedApps(packages: List<String>) {
        // Save to SharedPreferences (accessible by AccessibilityService)
        val prefs = getSharedPreferences(
            AppBlockerAccessibilityService.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        prefs.edit()
            .putString(AppBlockerAccessibilityService.KEY_BLOCKED_PACKAGES, packages.joinToString(","))
            .apply()

        // Also update running service instance if available
        AppBlockerAccessibilityService.instance?.updateBlockedPackages(packages)
    }

    private fun setBlockerEnabled(enabled: Boolean) {
        val prefs = getSharedPreferences(
            AppBlockerAccessibilityService.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        prefs.edit()
            .putBoolean(AppBlockerAccessibilityService.KEY_SERVICE_ENABLED, enabled)
            .apply()

        AppBlockerAccessibilityService.instance?.setEnabled(enabled)
    }

    private fun setChildModeActive(active: Boolean) {
        val prefs = getSharedPreferences(
            AppBlockerAccessibilityService.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        prefs.edit()
            .putBoolean(AppBlockerAccessibilityService.KEY_CHILD_MODE_ACTIVE, active)
            .apply()

        AppBlockerAccessibilityService.instance?.setChildMode(active)
    }

    private fun requestDeviceAdmin() {
        val componentName = ComponentName(this, ParentShieldDeviceAdmin::class.java)
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName)
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "ParentShield needs Device Admin to prevent uninstallation and protect your child."
            )
        }
        startActivityForResult(intent, DEVICE_ADMIN_REQUEST_CODE)
    }

    private fun isDeviceAdminActive(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val componentName = ComponentName(this, ParentShieldDeviceAdmin::class.java)
        return dpm.isAdminActive(componentName)
    }
}
