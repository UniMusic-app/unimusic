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
      Song(name: final name, artists: final artists, artwork: final artwork) => GenericItemTile(
        onTap: onTap,
        borderRadius: BorderRadiusGeometry.circular(LibraryItemType.songs.borderRadius),
        type: "Song",
        title: name,
        subtitle: artists.formatted,
        artwork: artwork,
        icon: Icon(LibraryItemType.songs.icon),
      ),
      Album(name: final name, artists: final artists, artwork: final artwork) => GenericItemTile(
        onTap: onTap,
        borderRadius: BorderRadiusGeometry.circular(LibraryItemType.albums.borderRadius),
        type: "Album",
        title: name,
        subtitle: artists.formatted,
        artwork: artwork,
        icon: Icon(LibraryItemType.albums.icon),
      ),
      Artist(name: final name, artwork: final artwork) => GenericItemTile(
        onTap: onTap,
        borderRadius: BorderRadiusGeometry.circular(LibraryItemType.artists.borderRadius),
        type: "Artist",
        title: name,
        artwork: artwork,
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
