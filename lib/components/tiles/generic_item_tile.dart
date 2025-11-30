import 'package:flutter/material.dart';
import 'package:unimusic/components/adaptive_context_menu.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/components/lazy_image.dart';

class TileAction {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const TileAction({required this.icon, required this.text, required this.onTap});
}

class GenericItemTile<T> extends StatelessWidget {
  final BorderRadiusGeometry borderRadius;
  final String type;
  final String title;
  final bool favourite;
  final String? subtitle;
  final Artwork? artwork;
  final Widget icon;
  final List<AdaptiveMenuItem>? menuItems;

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
    super.key,
  }) : super();

  @override
  Widget build(BuildContext context) {
    return AdaptiveContextMenu(
      items: [
        MenuHeader(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: borderRadius,
                child: LazyImage(artwork: artwork, icon: icon, width: 48, size: ArtworkSize.small),
              ),
              const SizedBox(width: 12),
              Column(
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
        dense: true,

        leading: ClipRRect(
          borderRadius: borderRadius,
          child: LazyImage(artwork: artwork, icon: icon, width: 48, size: ArtworkSize.small),
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
}
