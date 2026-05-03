import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:provider/provider.dart";
import "package:unimusic/components/airplay_route_picker_button.dart";
import "package:unimusic/services/music_manager.dart";

class AudioSourceView extends StatefulWidget {
  const AudioSourceView({super.key});

  static Future<void> show(BuildContext context) async {
    final musicManager = context.read<MusicManager>();
    await musicManager.refreshAudioRoutingCapabilities();
    await musicManager.refreshAudioRoute();
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AudioSourceView(),
    );
  }

  @override
  State<AudioSourceView> createState() => _AudioSourceViewState();
}

class _AudioSourceViewState extends State<AudioSourceView> {
  @override
  Widget build(BuildContext context) {
    final musicManager = context.watch<MusicManager>();
    final theme = Theme.of(context);
    final safeAreaBottom = MediaQuery.paddingOf(context).bottom;
    final isApple =
        (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);
    final canShowAirPlayPicker =
        isApple &&
        musicManager.audioRoutingCapabilities.hasNativeAirPlayPicker &&
        musicManager.audioRoutingCapabilities.hasExternalRoutes;

    final volume = musicManager.volume.clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + safeAreaBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Audio output", style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Symbols.volume_up_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Player volume",
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                "${(volume * 100).round()}%",
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            min: 0,
            max: 1,
            value: volume,
            onChanged: (value) {
              // Intentionally not debounced: updates can be spammed while dragging.
              musicManager.setVolume(value);
            },
          ),
          const SizedBox(height: 8),
          Text("Current output", style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              musicManager.currentRouteKind.icon,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(musicManager.currentRouteKind.title),
            subtitle: Text(
              musicManager.currentRouteKind.subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 8),
          if (!isApple)
            ListTile(
              dense: true,
              leading: const Icon(Symbols.tune_rounded),
              title: const Text("Choose output…"),
              subtitle: const Text("Open the system output chooser"),
              contentPadding: EdgeInsets.zero,
              enabled:
                  musicManager.audioRoutingCapabilities.canOpenSystemChooser,
              onTap: musicManager.audioRoutingCapabilities.canOpenSystemChooser
                  ? () => musicManager.openSystemOutputChooser()
                  : null,
            ),
          if (canShowAirPlayPicker)
            const ListTile(
              dense: true,
              leading: Icon(Symbols.airplay_rounded),
              title: Text("AirPlay"),
              subtitle: Text("Choose an AirPlay output"),
              contentPadding: EdgeInsets.zero,
              trailing: AirPlayRoutePickerButton(height: 36),
            ),
        ],
      ),
    );
  }
}
