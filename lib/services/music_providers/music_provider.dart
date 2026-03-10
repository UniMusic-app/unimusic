import 'dart:async';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

enum MusicItemType { song, album, artist }

abstract class MusicItem {
  final String providerId;
  final String id;
  final MusicItemType type;
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
  ArtworkType? artwork;

  Artist({
    required super.providerId,
    required super.id,
    required super.favourite,
    required this.name,
    this.artwork,
  }) : super(type: MusicItemType.artist);

  /// Returns the artwork for this artist.
  ///
  /// Implementations may override this method to fetch artwork on-demand if it
  /// wasn't loaded during artist initialization. However, this method may still
  /// return `null` if no artwork is available for the artist.
  ///
  /// Use this method instead of directly accessing the [artwork] property when
  /// you need to ensure all possible attempts to retrieve artwork have been made.
  Future<ArtworkType?> getArtwork() async => artwork;

  /// Returns featured songs of this artist.
  /// Typically "Top Songs", but may be different based on provider.
  Stream<Song> getFeaturedSongs({int? limit, int? startIndex});

  /// Get all albums of this artist.
  Stream<Album> getAlbums({int? limit, int? startIndex});

  /// Get all favourited songs and albums from this artist.
  Stream<MusicItem> getFavourites();
}

extension FormatArtists on Iterable<Artist> {
  String get formatted => map((artist) => artist.name).join(" & ");
}

typedef StreamInfoParts = ({
  String? format,
  int? bitrateKbps,
  int? sampleRateHz,
});

abstract class Song<ArtistType extends Artist, ArtworkType extends Artwork>
    extends MusicItem {
  final String name;
  final Duration duration;
  final String? album;
  final List<ArtistType> artists;
  final String? filePath;
  ArtworkType? artwork;

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
  }) : super(type: MusicItemType.song);

  Future<AudioSource> getAudioSource();

  /// Returns the artwork for this song.
  ///
  /// Implementations may override this method to fetch artwork on-demand if it
  /// wasn't loaded during artist initialization. However, this method may still
  /// return `null` if no artwork is available for the song.
  ///
  /// Use this method instead of directly accessing the [artwork] property when
  /// you need to ensure all possible attempts to retrieve artwork have been made.
  Future<ArtworkType?> getArtwork() async => artwork;

  /// Get the album of this song, if available.
  Future<Album?> getAlbum();

  /// Returns stream info label parts (format, bitrate, sample rate).
  /// Returns null if info cannot be determined.
  Future<StreamInfoParts?> getStreamInfoParts();
}

abstract class Album<ArtistType extends Artist, ArtworkType extends Artwork>
    extends MusicItem {
  final String name;
  final List<ArtistType> artists;
  ArtworkType? artwork;

  Album({
    required super.providerId,
    required super.id,
    required super.favourite,
    required this.name,
    required this.artists,
    this.artwork,
  }) : super(type: MusicItemType.album);

  /// Returns the artwork for this album.
  ///
  /// Implementations may override this method to fetch artwork on-demand if it
  /// wasn't loaded during artist initialization. However, this method may still
  /// return `null` if no artwork is available for the album.
  ///
  /// Use this method instead of directly accessing the [artwork] property when
  /// you need to ensure all possible attempts to retrieve artwork have been made.
  Future<ArtworkType?> getArtwork() async => artwork;

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
      null => StreamGroup.merge([
        getLibrarySongs(),
        getLibraryAlbums(),
        getLibraryArtists(),
      ]),
    };
  }

  Stream<SearchHint> getSearchHints({
    required String query,
    LibraryItemType? itemType,
  });
  Stream<MusicItem> getSearchResults({
    required String query,
    LibraryItemType? itemType,
  });

  Future<void> cleanupGarbage() async {}
}
