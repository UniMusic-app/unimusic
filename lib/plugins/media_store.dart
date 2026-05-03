import "dart:io";
import "package:flutter/services.dart";
import "package:unimusic/utils/null.dart";

class MediaStorePlugin {
  static const MethodChannel _channel = MethodChannel("media_store");

  static void _assertAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError("MediaStorePlugin is only supported on Android.");
    }
  }

  static bool isEmptyValue(String? value) {
    return switch (value) {
      ("" || "<unknown>" || null) => true,
      _ => false,
    };
  }

  static Future<Uint8List?> readArtwork(Uri artworkUri) async {
    _assertAndroid();
    final Uint8List result = (await _channel.invokeMethod<Uint8List>(
      "readArtwork",
      {"artworkUri": artworkUri.toString()},
    ))!;
    return result;
  }

  static Stream<MediaStoreSong> getSongs() async* {
    _assertAndroid();
    final result = (await _channel.invokeMethod<List<Object?>>("getSongs"))!;

    for (final value in result) {
      final map = Map<String, dynamic>.from(value as Map);
      final song = MediaStoreSong.fromMap(map);
      yield song;
    }
  }

  static Stream<MediaStoreSong> getAlbumSongs(String albumId) async* {
    _assertAndroid();
    final result = (await _channel.invokeMethod<List<Object?>>(
      "getAlbumSongs",
      {"albumId": albumId},
    ))!;
    for (final value in result) {
      final map = Map<String, dynamic>.from(value as Map);
      final song = MediaStoreSong.fromMap(map);
      yield song;
    }
  }

  static Stream<MediaStoreArtist> getArtists() async* {
    _assertAndroid();
    final result = (await _channel.invokeMethod<List<Object?>>("getArtists"))!;

    for (final value in result) {
      final map = Map<String, dynamic>.from(value as Map);
      final artist = MediaStoreArtist.fromMap(map);
      if (isEmptyValue(artist.name)) {
        continue;
      }
      yield artist;
    }
  }

  static Stream<MediaStoreAlbum> getAlbums() async* {
    _assertAndroid();
    final result = (await _channel.invokeMethod<List<Object?>>("getAlbums"))!;

    for (final value in result) {
      final map = Map<String, dynamic>.from(value as Map);
      final album = MediaStoreAlbum.fromMap(map);
      if (isEmptyValue(album.artist?.name)) {
        continue;
      }
      yield album;
    }
  }

  static Future<bool> checkPermission() async {
    _assertAndroid();
    final result = (await _channel.invokeMethod<bool>("checkPermission"))!;
    return result;
  }

  static Future<bool> requestPermission() async {
    _assertAndroid();
    final result = (await _channel.invokeMethod<bool>("requestPermission"))!;
    return result;
  }
}

class MediaStoreSong {
  final int id;
  final String name;
  final Duration duration;
  final Uri? artwork;

  final Uri path;
  final String mimeType;
  final int? bitrate;
  final int? size;

  final MediaStoreArtist? artist;

  final MediaStoreAlbum? album;
  final int? albumDisc;
  final int? albumTrack;

  const MediaStoreSong({
    required this.id,
    required this.name,
    required this.artist,
    required this.album,
    required this.duration,
    required this.path,
    required this.artwork,
    required this.albumDisc,
    required this.albumTrack,
    required this.mimeType,
    required this.bitrate,
    required this.size,
  });

  factory MediaStoreSong.fromMap(Map<String, dynamic> map) {
    final artworkUri = (map["artwork"] as String?).let(Uri.parse);

    final bitrateValue = map["bitrate"];
    final sizeValue = map["size"];
    final bitrate = bitrateValue is int && bitrateValue > 0
        ? bitrateValue
        : null;
    final size = sizeValue is int && sizeValue > 0 ? sizeValue : null;

    return MediaStoreSong(
      id: map["id"],
      name: map["name"],
      artist: switch (map["artist"]) {
        final artist when MediaStorePlugin.isEmptyValue(artist) => null,
        final artist => MediaStoreArtist(id: map["artistId"], name: artist),
      },
      album: MediaStoreAlbum(
        id: map["albumId"],
        name: map["album"],
        artist: switch (map["albumArtist"]) {
          String artist => MediaStoreArtist(id: map["albumId"], name: artist),
          _ => null,
        },
        artwork: artworkUri,
      ),
      albumTrack: map["albumTrack"],
      albumDisc: map["albumDisc"],
      mimeType: map["mimeType"],
      bitrate: bitrate,
      size: size,
      duration: Duration(milliseconds: map["duration"]),
      path: Uri.parse(map["path"] as String),
      artwork: artworkUri,
    );
  }

  int get albumHash => "$name/$albumDisc/$albumTrack".hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MediaStoreSong && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class MediaStoreArtist {
  final int id;
  final String name;

  MediaStoreArtist({required this.id, required this.name});

  factory MediaStoreArtist.fromMap(Map<String, dynamic> map) {
    return MediaStoreArtist(id: map["id"], name: map["name"]);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MediaStoreArtist && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class MediaStoreAlbum {
  final int id;
  final String name;
  final Uri? artwork;
  final MediaStoreArtist? artist;

  MediaStoreAlbum({
    required this.id,
    required this.name,
    this.artist,
    this.artwork,
  });

  factory MediaStoreAlbum.fromMap(Map<String, dynamic> map) {
    return MediaStoreAlbum(
      id: map["id"],
      name: map["name"],
      artist: switch (map["artist"]) {
        final artist when MediaStorePlugin.isEmptyValue(artist) => null,
        final artist => MediaStoreArtist(id: map["artistId"], name: artist),
      },
      artwork: (map["artwork"] as String?).let(Uri.parse),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MediaStoreAlbum && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
