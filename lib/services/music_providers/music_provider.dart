import 'dart:async';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

abstract class MusicItem {
  final String providerId;
  final String id;
  final String type;
  bool favourite;

  MusicItem({
    required this.providerId,
    required this.id,
    required this.type,
    required this.favourite,
  });

  Future<bool> isFavourite();
  Future<void> toggleFavourite(bool value);
}

enum ArtworkSize {
  large(1024),
  medium(256),
  small(96);

  final double width;
  const ArtworkSize(this.width);

  factory ArtworkSize.fromString(String sizeString) => switch (sizeString) {
    "small" => ArtworkSize.small,
    "medium" => ArtworkSize.medium,
    "large" => ArtworkSize.large,
    _ => throw Exception("Unknown ArtworkSize: $sizeString"),
  };

  @override
  String toString() => switch (this) {
    ArtworkSize.small => "small",
    ArtworkSize.medium => "medium",
    ArtworkSize.large => "large",
  };
}

abstract class Artwork {
  final String providerId;
  final String id;
  const Artwork({required this.providerId, required this.id});

  Uri? getImageUri(ArtworkSize size);
  ImageProvider? getImage(ArtworkSize size);
}

abstract class Artist<ArtworkType extends Artwork> extends MusicItem {
  final String name;
  final ArtworkType? artwork;

  Artist({
    required super.providerId,
    required super.id,
    required super.favourite,
    required this.name,
    this.artwork,
  }) : super(type: "Artist");
}

extension FormatArtists on Iterable<Artist> {
  String get formatted => map((artist) => artist.name).join(" & ");
}

abstract class Song<ArtistType extends Artist, ArtworkType extends Artwork> extends MusicItem {
  final String? filePath;
  final String name;
  final Duration duration;
  final String? album;
  final ArtworkType? artwork;
  final List<ArtistType> artists;

  Song({
    required super.providerId,
    required super.id,
    required super.favourite,
    required this.name,
    required this.artists,
    required this.duration,
    this.filePath,
    this.album,
    this.artwork,
  }) : super(type: "Song");

  Future<AudioSource> getAudioSource();
  Future<Album?> getAlbum();
}

abstract class Album<ArtistType extends Artist, ArtworkType extends Artwork> extends MusicItem {
  final String name;
  final ArtworkType? artwork;
  final List<ArtistType> artists;

  Album({
    required super.providerId,
    required super.id,
    required super.favourite,
    required this.name,
    required this.artists,
    this.artwork,
  }) : super(type: "Album");

  Stream<Song> getSongs();
}

abstract class SearchHint {
  final String title;
  final LibraryItemType? type;
  final Artwork? artwork;

  const SearchHint({required this.title, this.type, this.artwork});
}

enum LibraryItemType {
  songs("Song", 4, Icons.music_note),
  albums("Album", 12, Icons.album),
  artists("Artist", 9999, Icons.person);

  final String name;
  final double borderRadius;
  final IconData icon;

  const LibraryItemType(this.name, this.borderRadius, this.icon);
}

enum LibrarySortBy { album, artist, name }

enum LibrarySortOrder {
  ascending,
  descending;

  int toInt() => this == LibrarySortOrder.ascending ? 1 : -1;
  static LibrarySortOrder fromInt(int number) => switch (number) {
    1 => LibrarySortOrder.ascending,
    -1 => LibrarySortOrder.descending,
    _ => throw RangeError("LibrarySortOrder int is either 1 or -1"),
  };
}

abstract class MusicProvider {
  final String name;
  const MusicProvider(this.name);

  Stream<Song> getLibrarySongs();
  Stream<Album> getLibraryAlbums();
  Stream<Artist> getLibraryArtists();
  Stream<MusicItem> getLibraryItems({LibraryItemType? itemType}) async* {
    yield* switch (itemType) {
      LibraryItemType.songs => getLibrarySongs(),
      LibraryItemType.albums => getLibraryAlbums(),
      LibraryItemType.artists => getLibraryArtists(),
      null => StreamGroup.merge([getLibrarySongs(), getLibraryAlbums(), getLibraryArtists()]),
    };
  }

  Stream<SearchHint> getSearchHints({required String query, LibraryItemType? itemType});
  Stream<MusicItem> getSearchResults({required String query, LibraryItemType? itemType});

  Future<void> cleanupGarbage() async {}
}
