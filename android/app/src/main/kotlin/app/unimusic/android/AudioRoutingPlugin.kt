package app.unimusic.android

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class AudioRoutingPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private lateinit var applicationContext: Context
  private var activity: Activity? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "audio_routing")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getCapabilities" -> {
        result.success(
          mapOf(
            "canOpenSystemChooser" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R),
            "hasNativeAirPlayPicker" to false,
            "hasExternalRoutes" to false,
            // AudioManager.getDevices() is API 23+.
            "canDetectRoute" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M),
          ),
        )
      }

      "getCurrentRouteKind" -> {
        result.success(detectCurrentRouteKind())
      }

      "openSystemOutputChooser" -> {
        result.success(openSystemOutputChooser())
      }

      else -> result.notImplemented()
    }
  }

  private fun detectCurrentRouteKind(): String {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      // AudioManager.getDevices() isn't available, so we can't reliably detect routing.
      return "builtIn"
    }

    val audioManager = applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    val outputs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

    fun hasAnyOf(types: Set<Int>): Boolean = outputs.any { types.contains(it.type) }

    val wiredTypes = setOf(
      AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
      AudioDeviceInfo.TYPE_WIRED_HEADSET,
      AudioDeviceInfo.TYPE_USB_HEADSET,
      AudioDeviceInfo.TYPE_USB_DEVICE,
      AudioDeviceInfo.TYPE_USB_ACCESSORY,
      AudioDeviceInfo.TYPE_LINE_ANALOG,
      AudioDeviceInfo.TYPE_LINE_DIGITAL,
    )

    val bluetoothTypes = setOf(
      AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
      AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
      AudioDeviceInfo.TYPE_HEARING_AID,
    )

    // Best-effort signal only. Android doesn't provide a stable, app-agnostic
    // way to query the *active* media route for third-party players.
    return when {
      hasAnyOf(wiredTypes) -> "wired"
      hasAnyOf(bluetoothTypes) -> "bluetooth"
      else -> "builtIn"
    }
  }

  private fun openSystemOutputChooser(): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false

    val currentActivity = activity ?: return false

    fun tryStart(intent: Intent): Boolean {
      return try {
        val pm = currentActivity.packageManager
        if (intent.resolveActivity(pm) == null) return false
        currentActivity.startActivity(intent)
        true
      } catch (_: Exception) {
        false
      }
    }

    // Best-effort fallback chain:
    // 1) Attempt the media output panel (works on many Android builds but isn't guaranteed).
    // 2) Fall back to documented panels/settings screens.
    val candidates = listOf(
      Intent("com.android.settings.panel.action.MEDIA_OUTPUT"),
      Intent(Settings.Panel.ACTION_VOLUME),
      Intent(Settings.ACTION_SOUND_SETTINGS),
    )

    return candidates.any { tryStart(it) }
  }
}
