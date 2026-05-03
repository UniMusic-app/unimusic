import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:provider/provider.dart";
import "package:unimusic/services/music_manager.dart";

class PlaybackControls extends StatelessWidget {
  final double? iconSize;
  final double? playPauseIconSize;
  final bool filled;
  final double spacing;
  final bool compact;
  final ButtonStyle? style;

  const PlaybackControls({
    super.key,
    this.iconSize,
    this.playPauseIconSize,
    this.filled = false,
    this.spacing = 0,
    this.compact = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final musicManager = context.watch<MusicManager>();
    final constraints = compact ? const BoxConstraints() : null;
    final padding = compact ? const EdgeInsets.all(8) : null;
    final ppIconSize = playPauseIconSize ?? iconSize;

    final playPauseIcon = Icon(
      musicManager.isPlaying
          ? Symbols.pause_rounded
          : Symbols.play_arrow_rounded,
    );
    final playPauseOnPressed = musicManager.canPlay
        ? musicManager.togglePlayPause
        : null;
    final playPauseTooltip = musicManager.isPlaying ? "Pause" : "Play";

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: spacing,
      children: [
        IconButton(
          iconSize: iconSize,
          constraints: constraints,
          padding: padding,
          style: style,
          tooltip: "Previous",
          onPressed: musicManager.canSkipPrevious
              ? musicManager.skipPrevious
              : null,
          icon: const Icon(Symbols.skip_previous_rounded),
        ),
        if (filled)
          IconButton.filled(
            iconSize: ppIconSize,
            constraints: constraints,
            padding: padding,
            style: style,
            tooltip: playPauseTooltip,
            onPressed: playPauseOnPressed,
            icon: playPauseIcon,
          )
        else
          IconButton(
            iconSize: ppIconSize,
            constraints: constraints,
            padding: padding,
            style: style,
            tooltip: playPauseTooltip,
            onPressed: playPauseOnPressed,
            icon: playPauseIcon,
          ),
        IconButton(
          iconSize: iconSize,
          constraints: constraints,
          padding: padding,
          style: style,
          tooltip: "Next",
          onPressed: musicManager.canSkipNext ? musicManager.skipNext : null,
          icon: const Icon(Symbols.skip_next_rounded),
        ),
      ],
    );
  }
}
