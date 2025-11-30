import "dart:ui" as ui;
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:just_audio/just_audio.dart";
import "package:just_audio_background/just_audio_background.dart";
import "package:unimusic/plugins/media_store.dart";
import "package:unimusic/services/database/database.dart";
import "package:unimusic/services/music_providers/music_provider.dart";
import "package:unimusic/utils/null.dart";

const providerId = "local";

class LocalAndroidImage extends ImageProvider<LocalAndroidImage> {
  final Uri artworkUri;

  LocalAndroidImage(this.artworkUri);

  @override
  Future<LocalAndroidImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  Future<ui.Codec> _loadAsync(LocalAndroidImage key, ImageDecoderCallback decode) async {
    // TODO: This might not be very efficient
    final bytes = await MediaStorePlugin.readArtwork(artworkUri);
    if (bytes == null) {
      throw Exception("Failed reading artwork from $artworkUri: bytes is null");
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  ImageStreamCompleter loadImage(LocalAndroidImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'LocalAndroidImage(${key.artworkUri})',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LocalAndroidImage && other.artworkUri == artworkUri;

  @override
  int get hashCode => artworkUri.hashCode;
}

class LocalAndroidArtist extends Artist {
  LocalAndroidArtist({
    super.artwork,
    required super.id,
    required super.name,
    required super.favourite,
  }) : super(providerId: providerId);

  static Future<LocalAndroidArtist> fromMediaStore(MediaStoreArtist artist) async {
    final artistId = artist.id.toString();
    final existingDbArtist = await DatabaseHelper.getArtist(artistId);

    final localArtist = LocalAndroidArtist(
      id: artistId,
      name: artist.name,
      favourite: existingDbArtist?.favourite ?? false,
    );

    if (existingDbArtist == null) {
      await DatabaseHelper.insertArtist(localArtist);
    }

    return localArtist;
  }

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
}

class LocalAndroidArtwork extends Artwork {
  final Uri uri;

  const LocalAndroidArtwork({required super.id, required this.uri}) : super(providerId: providerId);

  factory LocalAndroidArtwork.fromMediaStore(Uri artworkUri) {
    // TODO: AlbumId might be better suited to be used as artwork id
    return LocalAndroidArtwork(id: artworkUri.toString(), uri: artworkUri);
  }

  @override
  ImageProvider<Object>? getImage(ArtworkSize size) {
    return LocalAndroidImage(uri);
  }

  @override
  Uri? getImageUri(ArtworkSize size) {
    return uri;
  }
}

class LocalAndroidAlbum extends Album<LocalAndroidArtist, LocalAndroidArtwork> {
  LocalAndroidAlbum({
    required super.id,
    required super.name,
    required super.artists,
    required super.favourite,
    super.artwork,
  }) : super(providerId: providerId);

  static Future<LocalAndroidAlbum> fromMediaStore(MediaStoreAlbum album) async {
    final albumId = album.id.toString();
    final existingDbAlbum = await DatabaseHelper.getAlbum(albumId);

    final artist = await album.artist.let(LocalAndroidArtist.fromMediaStore);
    final artists = [if (artist != null) artist];

    final localAlbum = LocalAndroidAlbum(
      id: albumId,
      name: album.name,
      artists: artists,
      artwork: album.artwork.let(LocalAndroidArtwork.fromMediaStore),
      favourite: existingDbAlbum?.favourite ?? false,
    );

    if (existingDbAlbum == null) {
      await DatabaseHelper.insertAlbum(localAlbum);
    }

    return localAlbum;
  }

  @override
  Stream<LocalAndroidSong> getSongs() async* {
    final Set<int> yieldedSongs = {};

    // TODO: Better recognition of songs<->albums, so this bs isn't needed
    await for (final song in MediaStorePlugin.getAlbumSongs(id)) {
      if (yieldedSongs.contains(song.albumHash)) {
        continue;
      }
      yieldedSongs.add(song.albumHash);
      yield await LocalAndroidSong.fromMediaStore(song);
    }
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

class LocalAndroidSong extends Song<Artist, LocalAndroidArtwork> {
  final Uri uri;

  LocalAndroidSong({
    super.artwork,
    required this.uri,
    required super.id,
    required super.name,
    required super.favourite,
    required super.artists,
    required super.album,
    required super.duration,
  }) : super(providerId: providerId);

  static Future<LocalAndroidSong> fromMediaStore(MediaStoreSong song) async {
    final artwork = song.artwork.let(LocalAndroidArtwork.fromMediaStore);
    final artist = await song.artist.let(LocalAndroidArtist.fromMediaStore);
    final albumArtist = await song.album?.artist.let(LocalAndroidArtist.fromMediaStore);

    final List<LocalAndroidArtist> artists = [
      if (albumArtist != null && albumArtist.name != artist?.name) albumArtist,
      if (artist != null) artist,
    ];

    final songId = song.id.toString();

    final existingDbSong = await DatabaseHelper.getSong(songId);

    final localSong = LocalAndroidSong(
      id: songId,
      name: song.name,
      favourite: existingDbSong?.favourite ?? false,
      album: song.album?.name,
      artwork: artwork,
      duration: song.duration,
      artists: artists,
      uri: song.path,
    );

    if (existingDbSong == null) {
      await DatabaseHelper.insertSong(localSong);
      if (song.album != null) {
        await DatabaseHelper.insertAlbumSong(song.album!.id.toString(), localSong.id);
      }
    }

    return localSong;
  }

  @override
  Future<AudioSource> getAudioSource() async {
    return AudioSource.uri(
      uri,
      tag: MediaItem(id: id, title: name, artUri: artwork?.uri),
    );
  }

  @override
  Future<Album> getAlbum() {
    // TODO: implement getAlbum
    throw UnimplementedError();
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
