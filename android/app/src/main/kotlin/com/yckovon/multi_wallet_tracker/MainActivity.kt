package com.yckovon.multi_wallet_tracker

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val settingsChannel =
        "com.yckovon.multi_wallet_tracker/app_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            settingsChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                        putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    }
                    result.success(startSettingsIntent(intent))
                }
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager =
                        getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(
                        powerManager.isIgnoringBatteryOptimizations(packageName),
                    )
                }
                "openBatteryOptimizationSettings" -> {
                    val intent = Intent(
                        Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS,
                    )
                    if (!startSettingsIntent(intent)) {
                        val fallback = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName"),
                        )
                        result.success(startSettingsIntent(fallback))
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startSettingsIntent(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (error: Exception) {
            false
        }
    }
}
