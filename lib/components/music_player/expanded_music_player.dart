import 'dart:math';

import 'package:flutter/material.dart';
import 'package:unimusic/components/lazy_image.dart';
import 'package:unimusic/services/music_manager.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/utils/duration.dart';
import 'package:provider/provider.dart';

class ExpandedMusicPlayer extends StatefulWidget {
  final double maxHeight;
  final AnimationController animationController;
  const ExpandedMusicPlayer({
    super.key,
    required this.maxHeight,
    required this.animationController,
  });

  @override
  State<ExpandedMusicPlayer> createState() => ExpandedMusicPlayerState();
}

class ExpandedMusicPlayerState extends State<ExpandedMusicPlayer> {
  @override
  Widget build(BuildContext context) {
    final musicManager = context.watch<MusicManager>();
    final currentItem = musicManager.currentItem;

    // SafeArea doesn't seem to work outside of Scaffold's body, so we calculate it ourselves
    final view = View.of(context);
    final safeAreaPadding = MediaQueryData.fromView(view).padding;

    final size = MediaQuery.sizeOf(context);

    final double artworkWidth = min(size.width - 48, size.height - 384);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24 + safeAreaPadding.horizontal),
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: widget.maxHeight,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: safeAreaPadding.top * widget.animationController.value),
              child: Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Expanded(
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
                        IconButton(onPressed: () {}, icon: Icon(Icons.shuffle_rounded)),
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
                              icon: Icon(Icons.skip_previous_rounded),
                            ),
                            // Play/pause
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              iconSize: 48,
                              onPressed: musicManager.canPlay ? musicManager.togglePlayPause : null,
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
                              onPressed: musicManager.canSkipNext ? musicManager.skipNext : null,
                              icon: Icon(Icons.skip_next_rounded),
                            ),
                          ],
                        ),
                        FutureBuilder(
                          future: currentItem?.isFavourite(),
                          builder: (context, snapshot) {
                            if (snapshot.data != null) {
                              return IconButton(
                                color: Colors.pinkAccent,
                                onPressed: () async {
                                  await currentItem?.toggleFavourite(!snapshot.data!);
                                  setState(() {});
                                },
                                icon: Icon(
                                  snapshot.data!
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_outline_rounded,
                                ),
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
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //   children: [
                  //     Text(
                  //       (_seekBarPosition ?? musicManager.position).formatted,
                  //       style: Theme.of(context).textTheme.labelSmall,
                  //     ),
                  //     Text("FLAC or whatever TODO"),
                  //     Text(
                  //       (-(musicManager.duration - musicManager.position)).formatted,
                  //       style: Theme.of(context).textTheme.labelSmall,
                  //     ),
                  //   ],
                  // ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(onPressed: null, icon: Icon(Icons.lyrics)),
                        IconButton(onPressed: null, icon: Icon(Icons.speaker)),
                        IconButton(onPressed: null, icon: Icon(Icons.queue_music)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpandedMusicPlayerSeekbar extends StatefulWidget {
  const ExpandedMusicPlayerSeekbar({super.key});

  @override
  State<ExpandedMusicPlayerSeekbar> createState() => ExpandedMusicPlayerSeekbarState();
}

class ExpandedMusicPlayerSeekbarState extends State<ExpandedMusicPlayerSeekbar> {
  Duration? _seekBarPosition;

  @override
  Widget build(BuildContext context) {
    final musicManager = context.watch<MusicManager>();

    final max = musicManager.duration.inMilliseconds.toDouble();
    final value = min((_seekBarPosition ?? musicManager.position).inMilliseconds.toDouble(), max);

    return Column(
      children: [
        Slider(
          min: 0,
          value: value,
          max: max,
          padding: EdgeInsets.zero,
          year2023: false,
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
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text("FLAC or whatever TODO"),
            Text(
              (-(musicManager.duration - musicManager.position)).formatted,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}
