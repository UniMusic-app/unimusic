import 'package:flutter/material.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/components/lazy_image.dart';

class MusicItemTile extends StatelessWidget {
  final MusicItem item;
  final void Function()? onTap;

  const MusicItemTile({required this.item, this.onTap, super.key}) : super();

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      Song song => GenericItemTile(
        onTap: onTap,
        borderRadius: BorderRadiusGeometry.circular(LibraryItemType.songs.borderRadius),
        type: "Song",
        title: song.name,
        subtitle: song.artists.formatted,
        favourite: song.favourite,
        artwork: song.artwork,
        icon: Icon(LibraryItemType.songs.icon),
      ),
      Album album => GenericItemTile(
        onTap: onTap,
        borderRadius: BorderRadiusGeometry.circular(LibraryItemType.albums.borderRadius),
        type: "Album",
        title: album.name,
        favourite: album.favourite,
        subtitle: album.artists.formatted,
        artwork: album.artwork,
        icon: Icon(LibraryItemType.albums.icon),
      ),
      Artist artist => GenericItemTile(
        onTap: onTap,
        borderRadius: BorderRadiusGeometry.circular(LibraryItemType.artists.borderRadius),
        type: "Artist",
        title: artist.name,
        artwork: artist.artwork,
        favourite: artist.favourite,
        icon: Icon(LibraryItemType.artists.icon),
      ),
      _ => throw UnimplementedError(),
    };
  }
}

class GenericItemTile<T> extends StatelessWidget {
  final BorderRadiusGeometry borderRadius;
  final String type;
  final String title;
  final bool favourite;
  final String? subtitle;
  final Artwork? artwork;
  final Widget icon;
  final void Function()? onTap;

  const GenericItemTile({
    required this.borderRadius,
    required this.type,
    required this.title,
    required this.icon,
    required this.artwork,
    required this.favourite,
    this.onTap,
    this.subtitle,
    super.key,
  }) : super();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,

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
    );
  }
}
