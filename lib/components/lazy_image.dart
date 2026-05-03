import "package:flutter/material.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class LazyImage extends StatefulWidget {
  final Artwork? artwork;
  final Widget icon;
  final double? width;
  final double? height;
  final ArtworkSize size;
  final Duration? animationDuration;

  const LazyImage({
    super.key,
    required this.artwork,
    required this.icon,
    required this.size,
    this.width,
    this.height,
    this.animationDuration,
  });

  @override
  State<StatefulWidget> createState() => LazyImageState();
}

class LazyImageState extends State<LazyImage> {
  ImageProvider? image;
  ImageProvider? oldImage;

  @override
  void initState() {
    super.initState();
    image = widget.artwork?.getImage(widget.size);
  }

  @override
  void didUpdateWidget(covariant LazyImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.artwork != oldWidget.artwork || widget.size != oldWidget.size) {
      _loadImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = _buildPlaceholder(context);
    final currentImage = image;

    if (currentImage != null) {
      return Image(
        image: currentImage,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
        fit: BoxFit.fill,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) {
            return child;
          }

          return Stack(
            fit: StackFit.passthrough,
            children: [
              placeholder,
              AnimatedOpacity(
                opacity: frame != null ? 1 : 0,
                duration:
                    widget.animationDuration ??
                    const Duration(milliseconds: 350),
                curve: Curves.easeInSine,
                child: child,
              ),
            ],
          );
        },
      );
    }

    return placeholder;
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (oldImage != null) {
      return Image(
        image: oldImage!,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
        fit: BoxFit.fill,
      );
    }

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadiusGeometry.all(Radius.circular(12)),
      ),
      child: AspectRatio(aspectRatio: 1, child: widget.icon),
    );
  }

  void _loadImage() {
    final nextImage = widget.artwork?.getImage(widget.size);
    if (nextImage == image) {
      return;
    }

    setState(() {
      oldImage = nextImage == null ? null : image;
      image = nextImage;
    });
  }
}
