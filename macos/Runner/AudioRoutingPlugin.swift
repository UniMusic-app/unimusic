import AVKit
import Cocoa
import FlutterMacOS

final class AirPlayRoutePickerPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withViewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> NSView {
    let container = NSView(frame: .zero)

    let picker = AVRoutePickerView(frame: .zero)
    picker.translatesAutoresizingMaskIntoConstraints = false

    container.addSubview(picker)

    NSLayoutConstraint.activate([
      picker.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      picker.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      picker.topAnchor.constraint(equalTo: container.topAnchor),
      picker.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])

    return container
  }
}

public class AudioRoutingPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "audio_routing", binaryMessenger: registrar.messenger)
    let instance = AudioRoutingPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    registrar.register(AirPlayRoutePickerPlatformViewFactory(), withId: "audio_routing_airplay_button")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getCapabilities":
      result([
        "canOpenSystemChooser": false,
        "hasNativeAirPlayPicker": true,
        // Best-effort: macOS doesn't expose route availability in a stable public API
        // comparable to iOS AVAudioSession. We default true so the native picker can
        // decide whether to show anything.
        "hasExternalRoutes": true,
        "canDetectRoute": false,
      ])

    case "getCurrentRouteKind":
      // macOS doesn't expose AVAudioSession-style route info in a stable way.
      result("unknown")

    case "openSystemOutputChooser":
      result(false)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
