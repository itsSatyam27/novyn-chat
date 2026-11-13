package com.example.novyn

import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.media.AudioDeviceInfo
import android.media.AudioDeviceCallback
import android.os.Handler
import android.os.Looper
import android.content.pm.PackageManager
import android.content.ComponentName
import android.os.Vibrator
import android.os.VibrationEffect
import android.os.Build
import android.app.PictureInPictureParams
import android.util.Rational
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.view.WindowManager

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.example.novyn/audio"
    private val SECURITY_CHANNEL = "com.example.novyn/security"
    private val CALL_CHANNEL = "com.example.novyn/call"
    private val AUDIO_ROUTE_EVENTS = "com.example.novyn/audio_routes"
    private var audioRouteSink: EventChannel.EventSink? = null
    private var audioDeviceCallback: AudioDeviceCallback? = null
    private var communicationDeviceListener: AudioManager.OnCommunicationDeviceChangedListener? = null
    private var scoStateReceiver: BroadcastReceiver? = null

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
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            audioManager.clearCommunicationDevice()
                        } else {
                            @Suppress("DEPRECATION")
                            audioManager.isSpeakerphoneOn = false
                            @Suppress("DEPRECATION")
                            audioManager.stopBluetoothSco()
                        }
                        result.success(null)
                    }
                    "getAudioRoutes" -> result.success(getCallAudioRoutes(audioManager))
                    "setAudioRoute" -> {
                        val routeId = call.argument<String>("routeId") ?: ""
                        result.success(selectCallAudioRoute(audioManager, routeId))
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
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            audioManager.clearCommunicationDevice()
                        } else {
                            @Suppress("DEPRECATION")
                            audioManager.stopBluetoothSco()
                            @Suppress("DEPRECATION")
                            audioManager.isBluetoothScoOn = false
                            @Suppress("DEPRECATION")
                            audioManager.isSpeakerphoneOn = false
                        }
                        audioManager.isMicrophoneMute = false
                        audioManager.mode = AudioManager.MODE_NORMAL
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_ROUTE_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    audioRouteSink = events
                    val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        communicationDeviceListener = AudioManager.OnCommunicationDeviceChangedListener {
                            publishCallAudioRoutes(manager)
                        }
                        manager.addOnCommunicationDeviceChangedListener(mainExecutor, communicationDeviceListener!!)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        audioDeviceCallback = object : AudioDeviceCallback() {
                            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
                                publishCallAudioRoutes(manager)
                            }
                            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
                                publishCallAudioRoutes(manager)
                            }
                        }
                        manager.registerAudioDeviceCallback(audioDeviceCallback, Handler(Looper.getMainLooper()))
                    }
                    // Android 7–11 use Bluetooth SCO for headset call audio. SCO
                    // connection is asynchronous, so wait for the system state
                    // broadcast before marking the route active.
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                        scoStateReceiver = object : BroadcastReceiver() {
                            override fun onReceive(context: Context?, intent: Intent?) {
                                if (intent?.action != AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED) return
                                val state = intent.getIntExtra(
                                    AudioManager.EXTRA_SCO_AUDIO_STATE,
                                    AudioManager.SCO_AUDIO_STATE_ERROR
                                )
                                @Suppress("DEPRECATION")
                                manager.isBluetoothScoOn = state == AudioManager.SCO_AUDIO_STATE_CONNECTED
                                publishCallAudioRoutes(manager)
                            }
                        }
                        val filter = IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            registerReceiver(scoStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                        } else {
                            registerReceiver(scoStateReceiver, filter)
                        }
                    }
                    publishCallAudioRoutes(manager)
                }

                override fun onCancel(arguments: Any?) {
                    val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        communicationDeviceListener?.let { manager.removeOnCommunicationDeviceChangedListener(it) }
                    }
                    communicationDeviceListener = null
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        audioDeviceCallback?.let { manager.unregisterAudioDeviceCallback(it) }
                    }
                    audioDeviceCallback = null
                    scoStateReceiver?.let {
                        try {
                            unregisterReceiver(it)
                        } catch (_: IllegalArgumentException) {
                        }
                    }
                    scoStateReceiver = null
                    audioRouteSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPictureInPicture" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            try {
                                val params = PictureInPictureParams.Builder()
                                    .setAspectRatio(Rational(9, 16))
                                    .build()
                                result.success(enterPictureInPictureMode(params))
                            } catch (error: IllegalArgumentException) {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
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
                } else if (call.method == "vibratePattern") {
                    val timings = (call.argument<List<Number>>("timings") ?: emptyList())
                        .map { it.toLong().coerceAtLeast(0L) }.toLongArray()
                    val amplitudes = (call.argument<List<Number>>("amplitudes") ?: emptyList())
                        .map { it.toInt().coerceIn(0, 255) }.toIntArray()
                    val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                    if (vibrator.hasVibrator() && timings.isNotEmpty() && timings.size == amplitudes.size) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            vibrator.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
                        } else {
                            vibrator.vibrate(timings, -1)
                        }
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
    private fun getCallAudioRoutes(audioManager: AudioManager): List<Map<String, Any>> {
        val routes = mutableListOf<Map<String, Any>>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val available = audioManager.availableCommunicationDevices
            val selectedId = audioManager.communicationDevice?.id
            for (device in available) {
                val bluetooth = device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                    device.type == AudioDeviceInfo.TYPE_BLE_HEADSET
                val id = when (device.type) {
                    AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "earpiece"
                    AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
                    else -> if (bluetooth) "bluetooth:${device.id}" else continue
                }
                routes.add(mapOf(
                    "id" to id,
                    "name" to if (bluetooth) (device.productName?.toString()?.takeIf { it.isNotBlank() } ?: "Bluetooth") else if (id == "speaker") "Speaker" else "Phone",
                    "kind" to if (bluetooth) "bluetooth" else id,
                    "selected" to (selectedId == device.id)
                ))
            }
        } else {
            routes.add(mapOf("id" to "earpiece", "name" to "Phone", "kind" to "earpiece", "selected" to !audioManager.isSpeakerphoneOn && !audioManager.isBluetoothScoOn))
            routes.add(mapOf("id" to "speaker", "name" to "Speaker", "kind" to "speaker", "selected" to audioManager.isSpeakerphoneOn))
            @Suppress("DEPRECATION")
            val sco = audioManager.isBluetoothScoOn
            val bluetoothAvailable = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                .any { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO }
            if (bluetoothAvailable || sco) routes.add(mapOf("id" to "bluetooth:legacy", "name" to "Bluetooth headset", "kind" to "bluetooth", "selected" to sco))
        }
        return routes
    }

    private fun selectCallAudioRoute(audioManager: AudioManager, routeId: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val target = if (routeId.startsWith("bluetooth:")) {
                val deviceId = routeId.substringAfter(":").toIntOrNull() ?: return false
                audioManager.availableCommunicationDevices.firstOrNull { it.id == deviceId }
            } else {
                val type = if (routeId == "speaker") AudioDeviceInfo.TYPE_BUILTIN_SPEAKER else AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
                audioManager.availableCommunicationDevices.firstOrNull { it.type == type }
            } ?: return false
            val changed = audioManager.setCommunicationDevice(target)
            publishCallAudioRoutes(audioManager)
            return changed
        }

        @Suppress("DEPRECATION")
        if (routeId.startsWith("bluetooth:")) {
            // SCO negotiation can take a moment; the receiver above marks it
            // active only after Android reports SCO_AUDIO_STATE_CONNECTED.
            audioManager.isSpeakerphoneOn = false
            audioManager.isBluetoothScoOn = false
            audioManager.startBluetoothSco()
        } else if (routeId == "speaker") {
            audioManager.stopBluetoothSco()
            audioManager.isBluetoothScoOn = false
            audioManager.isSpeakerphoneOn = true
        } else {
            audioManager.stopBluetoothSco()
            audioManager.isBluetoothScoOn = false
            audioManager.isSpeakerphoneOn = false
        }
        publishCallAudioRoutes(audioManager)
        return true
    }

    private fun publishCallAudioRoutes(audioManager: AudioManager) {
        runOnUiThread {
            audioRouteSink?.success(getCallAudioRoutes(audioManager))
        }
    }

    }
}
