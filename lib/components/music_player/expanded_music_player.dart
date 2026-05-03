import "dart:math";
import "dart:ui";

import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:unimusic/components/music_player/views/audio_source_view.dart";
import "package:unimusic/components/music_player/views/controls_view.dart";
import "package:unimusic/components/music_player/views/queue_view.dart";

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
  bool _isAudioOutputSheetOpen = false;

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

  Future<void> _navigateToPage(int page) async {
    await _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.ease,
    );
  }

  @override
  Widget build(BuildContext context) {
    // SafeArea doesn't seem to work outside of Scaffold's body, so we calculate it ourselves
    final safeAreaPadding = MediaQueryData.fromView(View.of(context)).padding;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: widget.maxHeight,
        child: Column(
          children: [
            ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.only(
                  top: max(
                    8,
                    safeAreaPadding.top * widget.animationController.value,
                  ),
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
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      children: const [MusicControlsView(), MusicQueueView()],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: 16,
                      bottom: 32 + safeAreaPadding.bottom,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const IconButton(
                          onPressed: null,
                          icon: Icon(Symbols.lyrics_rounded),
                          tooltip: "Lyrics",
                        ),
                        IconButton(
                          isSelected: _isAudioOutputSheetOpen,
                          tooltip: "Audio output",
                          onPressed: () async {
                            setState(() {
                              _isAudioOutputSheetOpen = true;
                            });

                            await AudioSourceView.show(context);

                            if (!context.mounted) return;
                            setState(() {
                              _isAudioOutputSheetOpen = false;
                            });
                          },
                          icon: const Icon(Symbols.speaker_rounded),
                        ),
                        IconButton(
                          isSelected: _page == 1,
                          tooltip: "Queue",
                          onPressed: () async {
                            await _navigateToPage(
                              _pageController.page == 0 ? 1 : 0,
                            );
                          },
                          icon: const Icon(Symbols.queue_music_rounded),
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
