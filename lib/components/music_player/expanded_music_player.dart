import 'dart:math';

import 'package:flutter/material.dart';
import 'package:unimusic/components/music_player/views/controls_view.dart';
import 'package:unimusic/components/music_player/views/queue_view.dart';
import 'package:unimusic/services/music_manager.dart';
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
  final _pageController = PageController();
  int? _page;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _page = _pageController.page?.round();
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  _navigateToPage(int page) async {
    await _pageController.animateToPage(
      page,
      duration: Duration(milliseconds: 250),
      curve: Curves.ease,
    );
  }

  @override
  Widget build(BuildContext context) {
    // SafeArea doesn't seem to work outside of Scaffold's body, so we calculate it ourselves
    final view = View.of(context);
    final safeAreaPadding = MediaQueryData.fromView(view).padding;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: widget.maxHeight,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: max(8, safeAreaPadding.top * widget.animationController.value),
              ),
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
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      children: [MusicControlsView(), MusicQueueView()],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 32 + safeAreaPadding.bottom),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(onPressed: null, icon: Icon(Icons.lyrics)),
                        IconButton(onPressed: null, icon: Icon(Icons.speaker)),
                        IconButton(
                          isSelected: _page == 1,
                          onPressed: () async {
                            await _navigateToPage(_pageController.page == 0 ? 1 : 0);
                          },
                          icon: Icon(Icons.queue_music),
                        ),
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
            Text((_seekBarPosition ?? musicManager.position).formatted, style: textTimeStyle),
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
