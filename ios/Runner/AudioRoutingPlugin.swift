import AVFoundation
import Flutter
import MediaPlayer
import UIKit

final class AirPlayRoutePickerPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return AirPlayRoutePickerPlatformView(frame: frame)
  }
}

final class AirPlayRoutePickerPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView

  init(frame: CGRect) {
    container = UIView(frame: frame)
    super.init()

    let mpVolumeView = MPVolumeView(frame: .zero)
    mpVolumeView.translatesAutoresizingMaskIntoConstraints = false
    mpVolumeView.showsVolumeSlider = false
    mpVolumeView.showsRouteButton = true

    container.addSubview(mpVolumeView)

    NSLayoutConstraint.activate([
      mpVolumeView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      mpVolumeView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      mpVolumeView.topAnchor.constraint(equalTo: container.topAnchor),
      mpVolumeView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
  }

  func view() -> UIView {
    return container
  }
}

public class AudioRoutingPlugin: NSObject, FlutterPlugin {
  private let routeDetector: AVRouteDetector? = {
    if #available(iOS 11.0, *) {
      let detector = AVRouteDetector()
      detector.isRouteDetectionEnabled = true
      return detector
    }
    return nil
  }()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "audio_routing", binaryMessenger: registrar.messenger())
    let instance = AudioRoutingPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let factory = AirPlayRoutePickerPlatformViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "audio_routing_airplay_button")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getCapabilities":
      result([
        "canOpenSystemChooser": false,
        "hasNativeAirPlayPicker": true,
        "hasExternalRoutes": hasExternalRoutes(),
        "canDetectRoute": true,
      ])

    case "getCurrentRouteKind":
      result(detectCurrentRouteKind())

    case "openSystemOutputChooser":
      // iOS routing is exposed via the native route picker UI.
      result(false)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func detectCurrentRouteKind() -> String {
    let session = AVAudioSession.sharedInstance()
    guard let output = session.currentRoute.outputs.first else {
      return "unknown"
    }

    switch output.portType {
    case .airPlay:
      return "airplay"

    case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
      return "bluetooth"

    case .headphones, .headsetMic, .usbAudio:
      return "wired"

    case .builtInReceiver, .builtInSpeaker:
      return "builtIn"

    default:
      return "unknown"
    }
  }

  private func hasExternalRoutes() -> Bool {
    // Best-effort: prefer AVRouteDetector (wireless route availability).
    if #available(iOS 11.0, *) {
      if let routeDetector {
        return routeDetector.multipleRoutesDetected
      }
    }

    // Fallback: infer from current route (less accurate).
    let session = AVAudioSession.sharedInstance()
    let outputs = session.currentRoute.outputs
    if outputs.count > 1 { return true }
    guard let output = outputs.first else { return false }
    switch output.portType {
    case .airPlay, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .headphones, .headsetMic, .usbAudio:
      return true
    default:
      return false
    }
  }
}
