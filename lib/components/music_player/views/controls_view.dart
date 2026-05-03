import "dart:math";
import "package:flutter/material.dart";
import "package:just_audio/just_audio.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:provider/provider.dart";
import "package:unimusic/components/favourite_button.dart";
import "package:unimusic/components/lazy_image.dart";
import "package:unimusic/components/marquee_text.dart";
import "package:unimusic/components/playback_controls.dart";
import "package:unimusic/components/stream_info_label.dart";
import "package:unimusic/services/music_manager.dart";
import "package:unimusic/services/music_providers/music_provider.dart";
import "package:unimusic/utils/duration.dart";

class MusicControlsView extends StatelessWidget {
  const MusicControlsView({super.key});

  @override
  Widget build(BuildContext context) {
    final musicManager = context.watch<MusicManager>();
    final currentItem = musicManager.currentItem;
    final isShuffleEnabled = musicManager.isShuffleEnabled;
    final loopMode = musicManager.loopMode;

    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final double artworkWidth = max(0, min(size.width - 48, size.height - 384));

    final safeAreaPadding = MediaQuery.paddingOf(context);
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.only(
        left: 24 + safeAreaPadding.left,
        right: 24 + safeAreaPadding.right,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: LazyImage(
                animationDuration: const Duration(milliseconds: 350),
                icon: const Icon(Symbols.music_note_rounded),
                artwork: currentItem?.artwork,
                width: artworkWidth,
                size: ArtworkSize.large,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarqueeText(
                        text: currentItem?.name ?? "Nothing is playing",
                        style: theme.textTheme.headlineSmall,
                      ),
                      Text(
                        currentItem?.artists.formatted ?? "",
                        style: theme.textTheme.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Center(child: FavouriteButton(item: currentItem)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Shuffle button
                IconButton(
                  onPressed: musicManager.toggleShuffle,
                  icon: const Icon(Symbols.shuffle_rounded),
                  color: isShuffleEnabled ? activeColor : inactiveColor,
                  tooltip: isShuffleEnabled ? "Shuffle on" : "Shuffle off",
                ),
                // Play controls
                PlaybackControls(
                  iconSize: 48,
                  filled: true,
                  spacing: 8,
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                // Loop mode button
                IconButton(
                  onPressed: musicManager.cycleLoopMode,
                  icon: Icon(
                    loopMode == LoopMode.one
                        ? Symbols.repeat_one_rounded
                        : Symbols.repeat_rounded,
                  ),
                  color: loopMode == LoopMode.off ? inactiveColor : activeColor,
                  tooltip: switch (loopMode) {
                    LoopMode.off => "Loop off",
                    LoopMode.all => "Loop all",
                    LoopMode.one => "Loop one",
                  },
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: ExpandedMusicPlayerSeekbar(),
          ),
        ],
      ),
    );
  }
}

class ExpandedMusicPlayerSeekbar extends StatefulWidget {
  const ExpandedMusicPlayerSeekbar({super.key});

  @override
  State<ExpandedMusicPlayerSeekbar> createState() =>
      ExpandedMusicPlayerSeekbarState();
}

class ExpandedMusicPlayerSeekbarState
    extends State<ExpandedMusicPlayerSeekbar> {
  Duration? _seekBarPosition;

  @override
  Widget build(BuildContext context) {
    final musicManager = context.watch<MusicManager>();

    final maxValue = musicManager.duration.inMilliseconds.toDouble();
    final value = min(
      (_seekBarPosition ?? musicManager.position).inMilliseconds.toDouble(),
      maxValue,
    );
    final buffered = musicManager.bufferedPosition.inMilliseconds.toDouble();
    final bufferedValue = maxValue <= 0
        ? 0.0
        : max(min(buffered, maxValue), value);

    final theme = Theme.of(context);
    final textTimeStyle = theme.textTheme.labelSmall?.apply(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      children: [
        Slider(
          min: 0,
          value: value,
          max: maxValue,
          secondaryTrackValue: bufferedValue,
          padding: EdgeInsets.zero,
          onChanged: (value) {
            setState(() {
              _seekBarPosition = Duration(milliseconds: value.toInt());
            });
          },
          onChangeEnd: (value) async {
            await musicManager.seek(Duration(milliseconds: value.toInt()));
            _seekBarPosition = null;
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              (_seekBarPosition ?? musicManager.position).formatted,
              style: textTimeStyle,
            ),
            StreamInfoLabel(
              song: musicManager.currentItem,
              style: textTimeStyle?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              (-(musicManager.duration - musicManager.position)).formatted,
              style: textTimeStyle,
            ),
          ],
        ),
      ],
    );
  }
}
