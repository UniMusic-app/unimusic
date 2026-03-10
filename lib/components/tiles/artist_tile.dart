import 'package:flutter/material.dart';
import 'package:unimusic/components/adaptive_context_menu.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/views/pages/artist_page.dart';

import 'generic_item_tile.dart';

class ArtistTile extends StatelessWidget {
  final Artist artist;
  final TileAction? action;
  final List<AdaptiveMenuItem>? menuItems;
  final bool contained;
  final ContainedTilePosition containedPosition;

  const ArtistTile(
    this.artist, {
    super.key,
    this.action,
    this.menuItems,
    this.contained = false,
    this.containedPosition = ContainedTilePosition.single,
  });

  @override
  Widget build(BuildContext context) {
    return GenericItemTile(
      type: "Artist",
      icon: Icon(LibraryItemType.artists.icon),

      borderRadius: BorderRadius.circular(LibraryItemType.artists.borderRadius),

      title: artist.name,
      artwork: artist.artwork,
      favourite: artist.favourite,
      contained: contained,
      containedPosition: containedPosition,

      action:
          action ??
          TileAction(
            text: "Go to Artist Page",
            icon: Icons.person_rounded,
            onTap: () => _openArtistPage(context),
          ),

      menuItems: menuItems,
    );
  }

  void _openArtistPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ArtistPage(artist: artist)),
    );
  }
}
