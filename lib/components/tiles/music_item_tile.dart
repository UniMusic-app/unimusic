import 'package:flutter/material.dart';
import 'package:unimusic/components/tiles/album_tile.dart';
import 'package:unimusic/components/tiles/artist_tile.dart';
import 'package:unimusic/components/tiles/generic_item_tile.dart';
import 'package:unimusic/components/tiles/song_tile.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

class MusicItemTile extends StatelessWidget {
  final MusicItem item;
  final TileAction? action;
  const MusicItemTile(this.item, {super.key, this.action});

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      Song song => SongTile(song, action: action),
      Album album => AlbumTile(album, action: action),
      Artist artist => ArtistTile(artist, action: action),
      _ => throw Exception("Unknown MusciItem: $item"),
    };
  }
}
