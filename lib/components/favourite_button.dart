import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class FavouriteButton extends StatefulWidget {
  final MusicItem? item;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;

  const FavouriteButton({
    super.key,
    required this.item,
    this.iconSize,
    this.padding,
    this.constraints,
  });

  @override
  State<FavouriteButton> createState() => _FavouriteButtonState();
}

class _FavouriteButtonState extends State<FavouriteButton> {
  Future<bool>? _favouriteFuture;
  String? _lastItemId;

  @override
  void didUpdateWidget(covariant FavouriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshIfNeeded();
  }

  void _refreshIfNeeded() {
    final currentId = widget.item?.id;
    if (currentId != _lastItemId) {
      _lastItemId = currentId;
      _favouriteFuture = widget.item?.isFavourite();
    }
  }

  @override
  Widget build(BuildContext context) {
    _refreshIfNeeded();
    final item = widget.item;
    if (item == null) {
      return IconButton(
        onPressed: null,
        iconSize: widget.iconSize,
        constraints: widget.constraints,
        padding: widget.padding,
        icon: const Icon(Symbols.favorite_rounded, fill: 0),
      );
    }

    final theme = Theme.of(context);
    return FutureBuilder<bool>(
      future: _favouriteFuture,
      builder: (context, snapshot) {
        if (snapshot.data == null) {
          return IconButton(
            onPressed: null,
            iconSize: widget.iconSize,
            constraints: widget.constraints,
            padding: widget.padding,
            icon: const Icon(Symbols.favorite_rounded, fill: 0),
          );
        }
        return IconButton(
          iconSize: widget.iconSize,
          constraints: widget.constraints,
          padding: widget.padding,
          color: theme.colorScheme.error,
          tooltip: snapshot.data!
              ? "Remove from favourites"
              : "Add to favourites",
          icon: Icon(
            Symbols.favorite_rounded,
            fill: snapshot.data! ? 1 : 0,
            size: widget.iconSize,
          ),
          onPressed: () async {
            await item.toggleFavourite(!snapshot.data!);
            setState(() {
              _favouriteFuture = item.isFavourite();
            });
          },
        );
      },
    );
  }
}
