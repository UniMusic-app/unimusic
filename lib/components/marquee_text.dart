import "dart:math";
import "package:flutter/material.dart";

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration pause;
  final double velocity;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.pause = const Duration(milliseconds: 1200),
    this.velocity = 30,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _scrollController = ScrollController();
  int _scrollToken = 0;
  double _lastDistance = 0;
  bool _isScrolling = false;

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _stopScrolling();
    }
  }

  @override
  void dispose() {
    _scrollToken += 1;
    _scrollController.dispose();
    super.dispose();
  }

  void _stopScrolling() {
    _scrollToken += 1;
    _isScrolling = false;
    _lastDistance = 0;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _startScrolling(double distance) {
    if (distance <= 0) {
      _stopScrolling();
      return;
    }

    if (_isScrolling && (distance - _lastDistance).abs() < 0.5) {
      return;
    }

    _isScrolling = true;
    _lastDistance = distance;
    final token = ++_scrollToken;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollLoop(token, distance);
    });
  }

  Future<void> _scrollLoop(int token, double distance) async {
    final duration = _durationForDistance(distance);

    while (mounted && token == _scrollToken) {
      await Future.delayed(widget.pause);
      if (!mounted || token != _scrollToken) {
        break;
      }

      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          distance,
          duration: duration,
          curve: Curves.linear,
        );
      }

      await Future.delayed(widget.pause);
      if (!mounted || token != _scrollToken) {
        break;
      }

      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: duration,
          curve: Curves.linear,
        );
      }
    }
  }

  Duration _durationForDistance(double distance) {
    final ms = max(600, (distance / widget.velocity * 1000).round());
    return Duration(milliseconds: ms);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      _stopScrolling();
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(text: widget.text, style: widget.style);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();

        final maxWidth = constraints.maxWidth;
        if (textPainter.width <= maxWidth) {
          _stopScrolling();
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.textAlign,
          );
        }

        _startScrolling(textPainter.width - maxWidth);

        return ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.05, 0.95, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ClipRect(
            child: SizedBox(
              height: textPainter.height,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Text(
                  widget.text,
                  style: widget.style,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
