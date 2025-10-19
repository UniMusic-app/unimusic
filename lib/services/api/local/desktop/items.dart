import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unimusic/services/api/local/desktop/api.dart';
import 'package:unimusic/services/database/database.dart';
import 'package:unimusic/services/database/objects.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/services/database/cache.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class LocalArtwork extends Artwork {
  Uri? imageUri;
  LocalArtwork({required super.id}) : super(providerId: providerId);

  @override
  Uri? getImageUri(ArtworkSize size) {
    return imageUri;
  }

  @override
  ImageProvider? getImage(ArtworkSize size) {
    return _LocalArtworkImageProvider(artwork: this, artworkId: id, size: size);
  }
}

class _LocalArtworkImageProvider
    extends ImageProvider<_LocalArtworkImageProvider> {
  final LocalArtwork artwork;
  final String artworkId;
  final ArtworkSize size;

  const _LocalArtworkImageProvider({
    required this.artwork,
    required this.artworkId,
    required this.size,
  });

  @override
  Future<_LocalArtworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _LocalArtworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'LocalArtwork(${key.artworkId})',
    );
  }

  Future<ui.Codec> _loadAsync(
    _LocalArtworkImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final artworkInfo = await DatabaseHelper.getArtwork(
        key.artworkId,
        size: key.size,
      );

      if (artworkInfo == null) {
        throw Exception('Artwork ${key.artworkId} does not exist in databse');
      }

      final cachedFile = await CacheHelper.getArtworkFile(
        artworkInfo.id,
        artworkInfo.mimeType,
        artworkInfo.size,
      );

      if (cachedFile == null) {
        throw Exception('No image data available for artwork ${key.artworkId}');
      }

      artwork.imageUri = cachedFile.uri;
      final bytes = await cachedFile.readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return await decode(buffer);
    } catch (error) {
      throw Exception('Failed to load artwork ${key.artworkId}: $error');
    }
  }
}

class LocalArtist extends Artist<LocalArtwork> {
  final LocalDesktopApia api;

  LocalArtist({
    required this.api,
    required super.id,
    required super.name,
    super.artwork,
    super.favourite,
  }) : super(providerId: providerId);

  @override
  Future<bool> isFavourite() async {
    // For local files, we could implement favorites using a local database or file
    // For now, return the cached value or false
    return favourite ?? false;
  }

  @override
  Future<void> toggleFavourite(bool value) async {
    super.toggleFavourite(value);
    // TODO: Persist favorite status to local storage/database
  }

  static LocalArtist? fromDatabase(
    LocalDesktopApi api,
    ArtistDatabaseItem artist,
  ) {
    LocalArtwork? artwork;
    if (artist.artworkId != null) {
      artwork = LocalArtwork(id: artist.artworkId!);
    }
    return LocalArtist(
      api: api,
      id: artist.id,
      name: artist.name,
      artwork: artwork,
    );
  }
}

class LocalSong extends Song<LocalArtist, LocalArtwork> {
  final LocalDesktopApi api;
  final String filePath;

  LocalSong({
    required this.api,
    required super.id,
    required super.name,
    required super.artists,
    required super.album,
    required super.duration,
    required this.filePath,
    super.artwork,
    super.favourite,
  }) : super(providerId: providerId);

  static Future<LocalSong?> fromDatabase(
    LocalDesktopApi api,
    SongDatabaseItem song,
  ) async {
    final databaseArtists = await DatabaseHelper.getSongArtists(song.id);
    final artists = (databaseArtists)
        .map((artist) => LocalArtist.fromDatabase(api, artist))
        .whereType<LocalArtist>()
        .toList();

    LocalArtwork? artwork;
    if (song.artworkId != null) {
      artwork = LocalArtwork(id: song.artworkId!);
    }

    // In song the filePath is its id
    final filePath = song.id;

    return LocalSong(
      api: api,
      id: song.id,
      name: song.name,
      artists: artists,
      album: song.album,
      duration: Duration(milliseconds: song.duration),
      filePath: filePath,
      artwork: artwork,
    );
  }

  @override
  Future<AudioSource> getAudioSource() async {
    return AudioSource.file(
      filePath,
      tag: MediaItem(
        id: id,
        title: name,
        album: album,
        artist: artists.formatted,
        duration: duration,
        artUri: artwork?.getImageUri(ArtworkSize.medium),
      ),
    );
  }

  @override
  Future<bool> isFavourite() async {
    // For local files, we could implement favorites using a local database or file
    // For now, return the cached value or false
    return favourite ?? false;
  }

  @override
  Future<void> toggleFavourite(bool value) async {
    super.toggleFavourite(value);
    // TODO: Persist favorite status to local storage/database
  }
}

class LocalAlbum extends Album<LocalArtist, LocalArtwork> {
  final LocalDesktopApi api;

  LocalAlbum({
    required this.api,
    required super.id,
    required super.name,
    required super.artists,
    super.artwork,
    super.favourite,
  }) : super(providerId: providerId);

  static Future<LocalAlbum?> fromDatabase(
    LocalDesktopApi api,
    AlbumDatabaseItem album,
  ) async {
    final databaseArtists = await DatabaseHelper.getAlbumArtists(album.id);
    final artists = (databaseArtists)
        .map((artist) => LocalArtist.fromDatabase(api, artist))
        .whereType<LocalArtist>()
        .toList();

    LocalArtwork? artwork;
    if (album.artworkId != null) {
      artwork = LocalArtwork(id: album.artworkId!);
    }

    return LocalAlbum(
      api: api,
      id: album.id,
      name: album.name,
      artists: artists,
      artwork: artwork,
    );
  }

  @override
  Stream<Song> getSongs() async* {
    yield* api.getAlbumSongs(id);
  }

  @override
  Future<bool> isFavourite() async {
    // For local files, we could implement favorites using a local database or file
    // For now, return the cached value or false
    return favourite ?? false;
  }

  @override
  Future<void> toggleFavourite(bool value) async {
    super.toggleFavourite(value);
    // TODO: Persist favorite status to local storage/database
  }
}

class LocalSearchHint extends SearchHint {
  const LocalSearchHint({
    required super.title,
    required super.type,
    super.artwork,
  });
}
