import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unimusic/components/adaptive_context_menu.dart';
import 'package:unimusic/services/music_manager.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/views/pages/album_page.dart';
import 'package:unimusic/views/pages/artist_page.dart';

import 'generic_item_tile.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final TileAction? action;
  final List<AdaptiveMenuItem>? menuItems;
  final bool contained;
  final ContainedTilePosition containedPosition;

  const SongTile(
    this.song, {
    super.key,
    this.action,
    this.menuItems,
    this.contained = false,
    this.containedPosition = ContainedTilePosition.single,
  });

  @override
  Widget build(BuildContext context) {
    return GenericItemTile(
      type: "Song",
      icon: Icon(LibraryItemType.songs.icon),

      borderRadius: BorderRadius.circular(LibraryItemType.songs.borderRadius),

      title: song.name,
      subtitle: song.artists.formatted,
      favourite: song.favourite,
      artwork: song.artwork,
      contained: contained,
      containedPosition: containedPosition,

      action:
          action ??
          TileAction(
            text: "Play Now",
            icon: Icons.play_arrow_rounded,
            onTap: () => _playNow(context),
          ),

      menuItems: [
        if (song.album != null)
          MenuAction(
            title: "Go to Album",
            icon: Icons.album_rounded,
            onTap: () => _goToAlbum(context),
          ),

        if (song.artists.isNotEmpty)
          MenuAction(
            title: "Go to Artist",
            icon: Icons.person_rounded,
            onTap: () => _goToArtist(context),
          ),

        if (menuItems != null) ...menuItems!,
      ],
    );
  }

  Future<void> _playNow(BuildContext context) async {
    final musicManager = context.read<MusicManager>();
    await musicManager.playNow(song);
  }

  void _goToAlbum(BuildContext context) {
    AlbumPage.openAsync(context, song.getAlbum());
  }

  Future<void> _goToArtist(BuildContext context) async {
    if (song.artists.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtistPage(artist: song.artists.first),
      ),
    );
  }
}
