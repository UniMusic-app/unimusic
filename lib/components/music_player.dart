import 'package:flutter/material.dart';
import 'package:unimusic/components/music_player/expanded_music_player.dart';
import 'package:unimusic/components/bottom_sheet_bar.dart';
import 'package:unimusic/components/music_player/collapsed_music_player.dart';

class MusicPlayer extends StatefulWidget {
  const MusicPlayer({super.key});

  @override
  State<MusicPlayer> createState() => MusicPlayerState();
}

class MusicPlayerState extends State<MusicPlayer>
    with SingleTickerProviderStateMixin {
  static const double _minHeight = 64.0; // dense ListTile height with 2 lines
  late double _maxHeight;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, value: 0);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _animationController.value -= details.delta.dy / (_maxHeight - _minHeight);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;

    if (velocity.abs() > 700) {
      if (velocity > 0) {
        _collapse(const Duration(milliseconds: 250));
      } else {
        _expand(const Duration(milliseconds: 250));
      }
    } else {
      if (_animationController.value > 0.3) {
        _expand(const Duration(milliseconds: 300));
      } else {
        _collapse(const Duration(milliseconds: 300));
      }
    }
  }

  void _expand(Duration duration) {
    _animationController.animateTo(
      1,
      duration: duration,
      curve: Curves.easeOutSine,
    );
    BottomSheetBarNotification(duration: duration, value: 1).dispatch(context);
  }

  void _collapse(Duration duration) {
    _animationController.animateTo(
      0,
      duration: duration,
      curve: Curves.easeOutSine,
    );
    BottomSheetBarNotification(duration: duration, value: 0).dispatch(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    _maxHeight = size.height;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final currentHeight =
            _minHeight + (_maxHeight - _minHeight) * _animationController.value;

        return GestureDetector(
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,

          behavior: HitTestBehavior.opaque,
          child: Ink(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: SizedBox(
              height: currentHeight,
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 350),
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: _animationController.value > 0.3
                    ? Opacity(
                        opacity: (_animationController.value - 0.3) * (1 / 0.7),
                        child: ExpandedMusicPlayer(
                          animationController: _animationController,
                          maxHeight: _maxHeight,
                        ),
                      )
                    : Opacity(
                        opacity: 1 - (_animationController.value * (1 / 0.3)),
                        child: CollapsedMusicPlayer(
                          onTap: () =>
                              _expand(const Duration(milliseconds: 250)),
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
