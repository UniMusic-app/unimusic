import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

/// iOS-only AirPlay route picker button.
///
/// This is intentionally a thin wrapper around the platform-native control.
class AirPlayRoutePickerButton extends StatelessWidget {
  final double height;

  const AirPlayRoutePickerButton({super.key, this.height = 44});

  @override
  Widget build(BuildContext context) {
    if ({
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform)) {
      return SizedBox(
        width: height,
        height: height,
        child: defaultTargetPlatform == TargetPlatform.iOS
            ? UiKitView(
                viewType: "audio_routing_airplay_button",
                layoutDirection: Directionality.of(context),
              )
            : AppKitView(
                viewType: "audio_routing_airplay_button",
                layoutDirection: Directionality.of(context),
              ),
      );
    }
    return const SizedBox.shrink();
  }
}
