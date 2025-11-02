import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unimusic/services/api/local/shared/api.dart';
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

class _LocalArtworkImageProvider extends ImageProvider<_LocalArtworkImageProvider> {
  final LocalArtwork artwork;
  final String artworkId;
  final ArtworkSize size;

  const _LocalArtworkImageProvider({
    required this.artwork,
    required this.artworkId,
    required this.size,
  });

  @override
  Future<_LocalArtworkImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(_LocalArtworkImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'LocalArtwork(${key.artworkId})',
    );
  }

  Future<ui.Codec> _loadAsync(_LocalArtworkImageProvider key, ImageDecoderCallback decode) async {
    try {
      final artworkInfo = await DatabaseHelper.getArtwork(key.artworkId, size: key.size);

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
  final LocalSharedApi api;

  LocalArtist({
    required this.api,

    required super.id,
    required super.name,
    required super.favourite,
    super.artwork,
  }) : super(providerId: providerId);

  @override
  Future<bool> isFavourite() async {
    final artist = await DatabaseHelper.getArtist(id);
    return artist?.favourite ?? false;
  }

  @override
  Future<void> toggleFavourite(bool value) async {
    await DatabaseHelper.setFavourite("artist_items", id, value);
    favourite = value;
  }

  static LocalArtist fromDatabase(LocalSharedApi api, ArtistDatabaseItem artist) {
    LocalArtwork? artwork;
    if (artist.artworkId != null) {
      artwork = LocalArtwork(id: artist.artworkId!);
    }
    return LocalArtist(
      api: api,
      id: artist.id,
      name: artist.name,
      favourite: artist.favourite,
      artwork: artwork,
    );
  }
}

class LocalSong extends Song<LocalArtist, LocalArtwork> {
  final LocalSharedApi api;

  LocalSong({
    required this.api,
    required String filePath,

    required super.id,
    required super.name,
    required super.favourite,
    required super.artists,
    required super.duration,
    super.album,
    super.artwork,
  }) : super(providerId: providerId, filePath: filePath);

  static Future<LocalSong> fromDatabase(LocalSharedApi api, SongDatabaseItem song) async {
    final databaseArtists = await DatabaseHelper.getSongArtists(song.id);
    final artists = (databaseArtists)
        .map((artist) => LocalArtist.fromDatabase(api, artist))
        .whereType<LocalArtist>()
        .toList();

    LocalArtwork? artwork;
    if (song.artworkId != null) {
      artwork = LocalArtwork(id: song.artworkId!);
    }

    return LocalSong(
      api: api,
      id: song.id,
      name: song.name,
      favourite: song.favourite,
      artists: artists,
      album: song.album,
      duration: Duration(milliseconds: song.duration),
      filePath: song.filePath!,
      artwork: artwork,
    );
  }

  @override
  Future<AudioSource> getAudioSource() async {
    return AudioSource.file(
      filePath!,
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
    final song = await DatabaseHelper.getSong(id);
    return song?.favourite ?? false;
  }

  @override
  Future<void> toggleFavourite(bool value) async {
    await DatabaseHelper.setFavourite("song_items", id, value);
    favourite = value;
  }
}

class LocalAlbum extends Album<LocalArtist, LocalArtwork> {
  final LocalSharedApi api;

  LocalAlbum({
    required this.api,

    required super.id,
    required super.name,
    required super.favourite,
    required super.artists,
    super.artwork,
  }) : super(providerId: providerId);

  static Future<LocalAlbum> fromDatabase(LocalSharedApi api, AlbumDatabaseItem album) async {
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
      favourite: album.favourite,
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
    final album = await DatabaseHelper.getAlbum(id);
    return album?.favourite ?? false;
  }

  @override
  Future<void> toggleFavourite(bool value) async {
    await DatabaseHelper.setFavourite("album_items", id, value);
    favourite = value;
  }
}

class LocalSearchHint extends SearchHint {
  const LocalSearchHint({required super.title, required super.type, super.artwork});
}
