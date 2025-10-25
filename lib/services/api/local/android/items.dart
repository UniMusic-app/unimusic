import "dart:ui" as ui;
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:just_audio/just_audio.dart";
import "package:just_audio_background/just_audio_background.dart";
import "package:unimusic/plugins/media_store.dart";
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
  LocalAndroidArtist({super.artwork, super.favourite, required super.id, required super.name})
    : super(providerId: providerId);

  factory LocalAndroidArtist.fromMediaStore(MediaStoreArtist artist) {
    return LocalAndroidArtist(id: artist.id.toString(), name: artist.name);
  }

  @override
  Future<bool> isFavourite() async {
    // TODO: implement isFavourite
    return false;
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
    super.artwork,
    super.favourite,
  }) : super(providerId: providerId);

  factory LocalAndroidAlbum.fromMediaStore(MediaStoreAlbum album) {
    // TODO: AlbumId might be better suited to be used as artwork id
    final artist = album.artist.let(LocalAndroidArtist.fromMediaStore);
    final artists = [if (artist != null) artist];
    return LocalAndroidAlbum(
      id: album.id.toString(),
      name: album.name,
      artists: artists,
      artwork: album.artwork.let(LocalAndroidArtwork.fromMediaStore),
    );
  }

  @override
  Stream<LocalAndroidSong> getSongs() async* {
    final Set<int> yieldedSongs = {};

    await for (final song in MediaStorePlugin.getAlbumSongs(id)) {
      if (yieldedSongs.contains(song.albumHash)) {
        continue;
      }
      yieldedSongs.add(song.albumHash);
      yield LocalAndroidSong.fromMediaStore(song);
    }
  }

  @override
  Future<bool> isFavourite() async {
    // TODO: implement isFavourite
    return false;
  }
}

class LocalAndroidSong extends Song<Artist, LocalAndroidArtwork> {
  final Uri uri;

  LocalAndroidSong({
    super.artwork,
    required this.uri,
    required super.id,
    required super.name,
    required super.artists,
    required super.album,
    required super.duration,
  }) : super(providerId: providerId);

  factory LocalAndroidSong.fromMediaStore(MediaStoreSong song) {
    final artwork = song.artwork.let(LocalAndroidArtwork.fromMediaStore);
    final artist = song.artist.let(LocalAndroidArtist.fromMediaStore);
    final albumArtist = song.album?.artist.let(LocalAndroidArtist.fromMediaStore);

    final List<LocalAndroidArtist> artists = [
      if (albumArtist != null && albumArtist.name != artist?.name) albumArtist,
      if (artist != null) artist,
    ];

    return LocalAndroidSong(
      id: song.id.toString(),
      name: song.name,
      album: song.album?.name,
      artwork: artwork,
      duration: song.duration,
      artists: artists,
      uri: song.path,
    );
  }

  @override
  Future<AudioSource> getAudioSource() async {
    return AudioSource.uri(
      uri,
      tag: MediaItem(id: id, title: name, artUri: artwork?.uri),
    );
  }

  @override
  Future<bool> isFavourite() async {
    return false;
  }
}
