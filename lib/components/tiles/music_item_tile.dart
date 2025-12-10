import 'package:flutter/material.dart';
import 'package:unimusic/components/adaptive_context_menu.dart';
import 'package:unimusic/components/tiles/album_tile.dart';
import 'package:unimusic/components/tiles/artist_tile.dart';
import 'package:unimusic/components/tiles/generic_item_tile.dart';
import 'package:unimusic/components/tiles/song_tile.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

class MusicItemTile extends StatelessWidget {
  final MusicItem item;
  final TileAction? action;
  final List<AdaptiveMenuItem>? menuItems;
  const MusicItemTile(this.item, {super.key, this.action, this.menuItems});

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      Song song => SongTile(song, action: action, menuItems: menuItems),
      Album album => AlbumTile(album, action: action, menuItems: menuItems),
      Artist artist => ArtistTile(artist, action: action, menuItems: menuItems),
      _ => throw Exception("Unknown MusciItem: $item"),
    };
  }
}
