import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AudioRouteKind {
  builtIn('This device', 'Using built-in speakers', Icons.smartphone_rounded),
  wired('Headphones / wired', 'Using a wired output', Icons.headphones_rounded),
  bluetooth(
    'Bluetooth',
    'Using a Bluetooth device',
    Icons.speaker_group_rounded,
  ),
  airplay('AirPlay', 'Streaming via AirPlay', Icons.airplay_rounded),
  unknown(
    'System output',
    'Using the current system audio route',
    Icons.speaker_rounded,
  );

  final String title;
  final String subtitle;
  final IconData icon;

  const AudioRouteKind(this.title, this.subtitle, this.icon);

  static AudioRouteKind fromPlatformValue(Object? value) {
    final raw = value?.toString();
    switch (raw) {
      case 'builtIn':
        return AudioRouteKind.builtIn;
      case 'wired':
        return AudioRouteKind.wired;
      case 'bluetooth':
        return AudioRouteKind.bluetooth;
      case 'airplay':
        return AudioRouteKind.airplay;
      default:
        return AudioRouteKind.unknown;
    }
  }
}

@immutable
class AudioRoutingCapabilities {
  final bool canOpenSystemChooser;
  final bool hasNativeAirPlayPicker;

  /// Best-effort signal for whether an external route picker would actually show
  /// any options (AirPlay/Bluetooth/etc).
  ///
  /// On Apple platforms this is backed by native APIs and can change at runtime.
  /// On other platforms it may be a conservative default.
  final bool hasExternalRoutes;
  final bool canDetectRoute;

  const AudioRoutingCapabilities({
    required this.canOpenSystemChooser,
    required this.hasNativeAirPlayPicker,
    required this.hasExternalRoutes,
    required this.canDetectRoute,
  });

  factory AudioRoutingCapabilities.fromJson(Map<Object?, Object?> json) {
    bool readBool(String key) {
      final v = json[key];
      return v == true;
    }

    return AudioRoutingCapabilities(
      canOpenSystemChooser: readBool('canOpenSystemChooser'),
      hasNativeAirPlayPicker: readBool('hasNativeAirPlayPicker'),
      hasExternalRoutes: readBool('hasExternalRoutes'),
      canDetectRoute: readBool('canDetectRoute'),
    );
  }

  static const unsupported = AudioRoutingCapabilities(
    canOpenSystemChooser: false,
    hasNativeAirPlayPicker: false,
    hasExternalRoutes: false,
    canDetectRoute: false,
  );
}

class AudioRoutingService {
  static const MethodChannel _channel = MethodChannel('audio_routing');

  AudioRoutingCapabilities? _cachedCapabilities;

  Future<AudioRoutingCapabilities> getCapabilities({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedCapabilities != null) {
      return _cachedCapabilities!;
    }
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getCapabilities',
      );
      if (result == null) {
        return AudioRoutingCapabilities.unsupported;
      }
      final caps = AudioRoutingCapabilities.fromJson(result);
      _cachedCapabilities = caps;
      return caps;
    } catch (_) {
      return AudioRoutingCapabilities.unsupported;
    }
  }

  Future<AudioRouteKind> getCurrentRouteKind() async {
    try {
      final result = await _channel.invokeMethod<Object?>(
        'getCurrentRouteKind',
      );
      return AudioRouteKind.fromPlatformValue(result);
    } catch (_) {
      return AudioRouteKind.unknown;
    }
  }

  Future<bool> openSystemOutputChooser() async {
    try {
      final didOpen = await _channel.invokeMethod<bool>(
        'openSystemOutputChooser',
      );
      return didOpen == true;
    } catch (_) {
      // Best-effort.
      return false;
    }
  }
}

/// iOS-only AirPlay route picker button.
///
/// This is intentionally a thin wrapper around the platform-native control.
class AirPlayRoutePickerButton extends StatelessWidget {
  final double height;

  const AirPlayRoutePickerButton({super.key, this.height = 44});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb &&
        {
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      return SizedBox(
        width: height,
        height: height,
        child: defaultTargetPlatform == TargetPlatform.iOS
            ? UiKitView(
                viewType: 'audio_routing_airplay_button',
                layoutDirection: Directionality.of(context),
              )
            : AppKitView(
                viewType: 'audio_routing_airplay_button',
                layoutDirection: Directionality.of(context),
              ),
      );
    }
    return const SizedBox.shrink();
  }
}
