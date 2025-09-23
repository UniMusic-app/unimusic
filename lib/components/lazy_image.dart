import 'package:flutter/material.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/utils/pixels.dart';

class LazyImage extends StatefulWidget {
  final Artwork? artwork;
  final Widget icon;
  final double? width;
  final double? height;
  final int? quality;
  final Duration? animationDuration;

  const LazyImage({
    super.key,
    required this.artwork,
    required this.icon,
    this.width,
    this.height,
    this.quality,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadImage();
    });
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.artwork != oldWidget.artwork) {
      _loadImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = oldImage != null
        ? Image(
            image: oldImage!,
            width: widget.width,
            height: widget.height,
            gaplessPlayback: true,
            fit: BoxFit.fill,
          )
        : Container(
            width: widget.width,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadiusGeometry.all(Radius.circular(12)),
            ),
            child: AspectRatio(aspectRatio: 1, child: widget.icon),
          );

    if (image != null) {
      return AnimatedSwitcher(
        duration: widget.animationDuration ?? Duration(milliseconds: 350),
        switchInCurve: Curves.easeInOutSine,
        child: Image(
          key: ValueKey(image),
          image: image!,
          width: widget.width,
          height: widget.height,
          gaplessPlayback: true,
          fit: BoxFit.fill,

          frameBuilder:
              (BuildContext context, Widget child, int? frame, bool? wasSynchronouslyLoaded) {
                final visible = frame != null || wasSynchronouslyLoaded == true;
                return Stack(
                  children: [
                    placeholder,
                    AnimatedOpacity(
                      opacity: visible ? 1 : 0,
                      duration: widget.animationDuration ?? const Duration(milliseconds: 350),
                      curve: Curves.easeInSine,
                      child: child,
                    ),
                  ],
                );
              },
        ),
      );
    }

    return placeholder;
  }

  void _loadImage() {
    final image = widget.artwork?.getImage(
      width: widget.width?.logicalPixelsToDevicePixels(context),
      height: widget.height?.logicalPixelsToDevicePixels(context),
      quality: widget.quality,
    );

    oldImage = this.image;

    setState(() {
      this.image = image;
    });
  }
}
