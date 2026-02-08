import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:unimusic/components/lazy_image.dart';
import 'package:unimusic/services/music_manager.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/utils/duration.dart';

class MusicControlsView extends StatefulWidget {
  const MusicControlsView({super.key});

  @override
  State<StatefulWidget> createState() => MusicControlsViewState();
}

class MusicControlsViewState extends State<MusicControlsView> {
  @override
  Widget build(BuildContext context) {
    final musicManager = context.watch<MusicManager>();
    final currentItem = musicManager.currentItem;
    final isShuffleEnabled = musicManager.isShuffleEnabled;
    final loopMode = musicManager.loopMode;

    final size = MediaQuery.sizeOf(context);
    final double artworkWidth = min(size.width - 48, size.height - 384);

    final view = View.of(context);
    final safeAreaPadding = MediaQueryData.fromView(view).padding;
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24 + safeAreaPadding.horizontal,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              child: LazyImage(
                animationDuration: Duration(milliseconds: 350),
                icon: Icon(Icons.music_note),
                artwork: currentItem?.artwork,
                width: artworkWidth,
                size: ArtworkSize.large,
              ),
            ),
          ),
          // TODO: Marquee
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              currentItem?.name ?? "Nothing is playing",
              style: Theme.of(context).textTheme.headlineSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            currentItem?.artists.formatted ?? "",
            style: Theme.of(context).textTheme.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: musicManager.toggleShuffle,
                      icon: const Icon(Icons.shuffle_rounded),
                      color: isShuffleEnabled ? activeColor : inactiveColor,
                      tooltip: isShuffleEnabled ? 'Shuffle on' : 'Shuffle off',
                    ),
                    IconButton(
                      onPressed: musicManager.cycleLoopMode,
                      icon: Icon(
                        loopMode == LoopMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                      ),
                      color: loopMode == LoopMode.off
                          ? inactiveColor
                          : activeColor,
                      tooltip: switch (loopMode) {
                        LoopMode.off => 'Loop off',
                        LoopMode.all => 'Loop all',
                        LoopMode.one => 'Loop one',
                      },
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    // Skip to previous
                    IconButton(
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      iconSize: 48,
                      onPressed: musicManager.canSkipPrevious
                          ? musicManager.skipPrevious
                          : null,
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                    // Play/pause
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      iconSize: 48,
                      onPressed: musicManager.canPlay
                          ? musicManager.togglePlayPause
                          : null,
                      icon: Icon(
                        musicManager.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    // Skip to next
                    IconButton(
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      iconSize: 48,
                      onPressed: musicManager.canSkipNext
                          ? musicManager.skipNext
                          : null,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                  ],
                ),
                FutureBuilder(
                  future: currentItem?.isFavourite(),
                  builder: (context, snapshot) {
                    if (snapshot.data != null) {
                      return IconButton(
                        color: Colors.pinkAccent,
                        icon: AnimatedCrossFade(
                          duration: Duration(milliseconds: 150),
                          crossFadeState: snapshot.data!
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          firstChild: const Icon(Icons.favorite_rounded),
                          secondChild: const Icon(
                            Icons.favorite_outline_rounded,
                          ),
                        ),
                        onPressed: () async {
                          await currentItem?.toggleFavourite(!snapshot.data!);
                          setState(() {});
                        },
                      );
                    }

                    return IconButton(
                      onPressed: null,
                      icon: Icon(Icons.favorite_outline_rounded),
                    );
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

    final max = musicManager.duration.inMilliseconds.toDouble();
    final value = min(
      (_seekBarPosition ?? musicManager.position).inMilliseconds.toDouble(),
      max,
    );

    final textTimeStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.apply(fontFeatures: [FontFeature.tabularFigures()]);

    return Column(
      children: [
        Slider(
          min: 0,
          value: value,
          max: max,
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
            Text("FLAC or whatever TODO"),
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
