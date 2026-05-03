import "dart:ui";

import "package:flutter/material.dart";
import "package:unimusic/components/music_player/expanded_music_player.dart";
import "package:unimusic/components/bottom_sheet_bar.dart";
import "package:unimusic/components/music_player/collapsed_music_player.dart";

class MusicPlayer extends StatefulWidget {
  /// When true, the collapsed player renders as a floating pill.
  /// Should be true when placed inside a Stack on desktop layouts.
  final bool floating;

  /// Total height occupied by the floating collapsed player,
  /// including the bottom margin (_minHeight + _pillMargin).
  static const double collapsedFloatingHeight = 80.0;

  const MusicPlayer({super.key, this.floating = false});

  @override
  State<MusicPlayer> createState() => MusicPlayerState();
}

class MusicPlayerState extends State<MusicPlayer>
    with SingleTickerProviderStateMixin {
  static const double _minHeight = 64.0; // dense ListTile height with 2 lines
  static const double _pillMargin = 16.0;
  double _maxHeight = 0;
  late AnimationController _animationController;
  double? _dragStartValue;

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

  void _onDragStart(DragStartDetails details) {
    _dragStartValue = _animationController.value;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _animationController.value -= details.delta.dy / (_maxHeight - _minHeight);
  }

  void _onDragEnd(DragEndDetails details) {
    final startValue = _dragStartValue ?? _animationController.value;
    _dragStartValue = null;

    final moved = (_animationController.value - startValue).abs();
    final velocity = details.velocity.pixelsPerSecond.dy;

    // Ignore high-velocity gestures that barely moved the player -- these are
    // accidental micro-drags from trackpad taps stealing the gesture arena.
    if (velocity.abs() > 700 && moved > 0.02) {
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
    if (!widget.floating) {
      BottomSheetBarNotification(
        duration: duration,
        value: 1,
      ).dispatch(context);
    }
  }

  void _collapse(Duration duration) {
    _animationController.animateTo(
      0,
      duration: duration,
      curve: Curves.easeOutSine,
    );
    if (!widget.floating) {
      BottomSheetBarNotification(
        duration: duration,
        value: 0,
      ).dispatch(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    _maxHeight = size.height;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final value = _animationController.value;
        final currentHeight = _minHeight + (_maxHeight - _minHeight) * value;

        final playerContent = AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          child: value > 0.3
              ? Opacity(
                  opacity: (value - 0.3) * (1 / 0.7),
                  child: ExpandedMusicPlayer(
                    animationController: _animationController,
                    maxHeight: _maxHeight,
                  ),
                )
              : Opacity(
                  opacity: 1 - (value * (1 / 0.3)),
                  child: CollapsedMusicPlayer(
                    onTap: () => _expand(const Duration(milliseconds: 250)),
                  ),
                ),
        );

        if (widget.floating) {
          return _buildFloating(context, value, currentHeight, playerContent);
        }

        return _buildDocked(context, currentHeight, playerContent);
      },
    );
  }

  /// Docked layout (mobile): full-width, top-rounded, clip overflow.
  Widget _buildDocked(
    BuildContext context,
    double currentHeight,
    Widget content,
  ) {
    return GestureDetector(
      onVerticalDragStart: _onDragStart,
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
        child: ClipRect(
          child: SizedBox(height: currentHeight, child: content),
        ),
      ),
    );
  }

  /// Floating layout (desktop): pill that grows into a full overlay.
  Widget _buildFloating(
    BuildContext context,
    double value,
    double currentHeight,
    Widget content,
  ) {
    final theme = Theme.of(context);

    // Interpolate from pill shape to full overlay.
    final margin = _pillMargin * (1 - value);
    final borderRadius = lerpDouble(12, 0, value)!;
    final elevation = lerpDouble(3, 0, value)!;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(left: margin, right: margin, bottom: margin),
        child: GestureDetector(
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          behavior: HitTestBehavior.opaque,
          child: Material(
            color: theme.colorScheme.surfaceContainerHigh,
            elevation: elevation,
            shadowColor: theme.colorScheme.shadow,
            borderRadius: BorderRadius.circular(borderRadius),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(height: currentHeight, child: content),
          ),
        ),
      ),
    );
  }
}
