import 'package:flutter/material.dart';
import 'package:unimusic/components/adaptive_context_menu.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/views/pages/album_page.dart';

import 'generic_item_tile.dart';

class AlbumTile extends StatelessWidget {
  final Album album;
  final TileAction? action;
  final List<AdaptiveMenuItem>? menuItems;
  final bool contained;
  final ContainedTilePosition containedPosition;

  const AlbumTile(
    this.album, {
    super.key,
    this.action,
    this.menuItems,
    this.contained = false,
    this.containedPosition = ContainedTilePosition.single,
  });

  @override
  Widget build(BuildContext context) {
    return GenericItemTile(
      type: "Album",
      icon: Icon(LibraryItemType.albums.icon),

      borderRadius: BorderRadius.circular(LibraryItemType.albums.borderRadius),

      title: album.name,
      subtitle: album.artists.formatted,
      favourite: album.favourite,
      artwork: album.artwork,
      contained: contained,
      containedPosition: containedPosition,

      action:
          action ??
          TileAction(
            text: "Go to Album Page",
            icon: Icons.album_rounded,
            onTap: () => _openAlbumPage(context),
          ),

      menuItems: menuItems,
    );
  }

  void _openAlbumPage(BuildContext context) {
    AlbumPage.open(context, album);
  }
}
