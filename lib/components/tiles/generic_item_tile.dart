import "package:flutter/material.dart";
import "package:unimusic/components/adaptive_context_menu.dart";
import "package:unimusic/services/music_providers/music_provider.dart";
import "package:unimusic/components/lazy_image.dart";

enum ContainedTilePosition { single, first, middle, last }

class TileAction {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const TileAction({
    required this.icon,
    required this.text,
    required this.onTap,
  });
}

class GenericItemTile<T> extends StatelessWidget {
  static const double _containedOuterRadius = 20;
  static const double _containedInnerRadius = 4;

  final BorderRadiusGeometry borderRadius;
  final String type;
  final String title;
  final bool favourite;
  final String? subtitle;
  final Artwork? artwork;
  final Widget icon;
  final List<AdaptiveMenuItem>? menuItems;
  final bool contained;
  final ContainedTilePosition containedPosition;
  final TileAction action;

  const GenericItemTile({
    required this.borderRadius,
    required this.type,
    required this.title,
    required this.icon,
    required this.artwork,
    required this.favourite,
    required this.action,
    this.menuItems,
    this.subtitle,
    this.contained = false,
    this.containedPosition = ContainedTilePosition.single,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final containedShape = RoundedRectangleBorder(
      borderRadius: _borderRadiusForContainedPosition(containedPosition),
    );

    return AdaptiveContextMenu(
      items: [
        MenuHeader(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: borderRadius,
                child: LazyImage(
                  artwork: artwork,
                  icon: icon,
                  width: 48,
                  size: ArtworkSize.small,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      subtitle == null ? type : "$type · $subtitle",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        MenuDivider(),

        MenuAction(title: action.text, icon: action.icon, onTap: action.onTap),

        if (menuItems != null) ...menuItems!,
      ],

      child: ListTile(
        onTap: action.onTap,
        minTileHeight: 12,
        dense: !contained,
        shape: contained ? containedShape : null,
        tileColor: contained ? theme.colorScheme.surfaceContainerLow : null,
        contentPadding: contained
            ? const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 6)
            : null,

        leading: ClipRRect(
          borderRadius: borderRadius,
          child: LazyImage(
            artwork: artwork,
            icon: icon,
            width: 48,
            size: ArtworkSize.small,
          ),
        ),

        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          subtitle == null ? type : "$type · $subtitle",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  BorderRadius _borderRadiusForContainedPosition(
    ContainedTilePosition position,
  ) {
    return switch (position) {
      ContainedTilePosition.single => const BorderRadius.all(
        Radius.circular(_containedOuterRadius),
      ),
      ContainedTilePosition.first => const BorderRadius.only(
        topLeft: Radius.circular(_containedOuterRadius),
        topRight: Radius.circular(_containedOuterRadius),
        bottomLeft: Radius.circular(_containedInnerRadius),
        bottomRight: Radius.circular(_containedInnerRadius),
      ),
      ContainedTilePosition.middle => const BorderRadius.all(
        Radius.circular(_containedInnerRadius),
      ),
      ContainedTilePosition.last => const BorderRadius.only(
        topLeft: Radius.circular(_containedInnerRadius),
        topRight: Radius.circular(_containedInnerRadius),
        bottomLeft: Radius.circular(_containedOuterRadius),
        bottomRight: Radius.circular(_containedOuterRadius),
      ),
    };
  }
}
