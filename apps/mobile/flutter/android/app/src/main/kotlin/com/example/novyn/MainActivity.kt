package com.example.novyn

import android.content.Context
import android.media.AudioManager
import android.content.pm.PackageManager
import android.content.ComponentName
import android.os.Vibrator
import android.os.VibrationEffect
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.example.novyn/audio"
    private val SECURITY_CHANNEL = "com.example.novyn/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val audioManager =
                    getSystemService(Context.AUDIO_SERVICE) as AudioManager

                when (call.method) {
                    // Call once at call start — sets mode, defaults to earpiece
                    "startCallMode" -> {
                        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                        @Suppress("DEPRECATION")
                        audioManager.isSpeakerphoneOn = false
                        result.success(null)
                    }
                    // Toggle only — mode already set, no re-negotiation, no pause
                    "setSpeakerphoneOn" -> {
                        val enable = call.argument<Boolean>("enable") ?: false
                        @Suppress("DEPRECATION")
                        audioManager.isSpeakerphoneOn = enable
                        result.success(null)
                    }
                    // Mute/unmute mic — works before WebRTC peer connection exists
                    "setMicMute" -> {
                        val mute = call.argument<Boolean>("mute") ?: false
                        audioManager.isMicrophoneMute = mute
                        result.success(null)
                    }
                    // Call when call ends — restores normal audio
                    "resetMode" -> {
                        @Suppress("DEPRECATION")
                        audioManager.isSpeakerphoneOn = false
                        audioManager.isMicrophoneMute = false
                        audioManager.mode = AudioManager.MODE_NORMAL
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Security Channel for Stealth Mode
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "setSafeMode") {
                    val enable = call.argument<Boolean>("enable") ?: false
                    if (enable) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else if (call.method == "setStealthIcon") {
                    val enable = call.argument<Boolean>("enable") ?: false
                    val packageManager = packageManager
                    
                    val defaultAlias = ComponentName(this, "com.example.novyn.MainActivityDefault")
                    val stealthAlias = ComponentName(this, "com.example.novyn.MainActivityStealth")

                    if (enable) {
                        // Enable Stealth, Disable Default
                        packageManager.setComponentEnabledSetting(stealthAlias, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                        packageManager.setComponentEnabledSetting(defaultAlias, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                    } else {
                        // Enable Default, Disable Stealth
                        packageManager.setComponentEnabledSetting(defaultAlias, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                        packageManager.setComponentEnabledSetting(stealthAlias, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                    }
                    result.success(null)
                } else if (call.method == "vibrate") {
                    val duration = call.argument<Int>("duration") ?: 50
                    val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                    if (vibrator.hasVibrator()) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            vibrator.vibrate(VibrationEffect.createOneShot(duration.toLong(), VibrationEffect.DEFAULT_AMPLITUDE))
                        } else {
                            vibrator.vibrate(duration.toLong())
                        }
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
