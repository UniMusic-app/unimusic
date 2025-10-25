import 'package:flutter/services.dart';
import 'package:unimusic/utils/null.dart';

class MediaStorePlugin {
  static const MethodChannel _channel = MethodChannel('media_store');

  static bool isEmptyValue(String? value) {
    return switch (value) {
      ("" || "<unknown>" || null) => true,
      _ => false,
    };
  }

  static Future<Uint8List?> readArtwork(Uri artworkUri) async {
    try {
      final Uint8List result = await _channel.invokeMethod('readArtwork', {
        "artworkUri": artworkUri.toString(),
      });
      return result;
    } catch (e) {
      throw Exception('Failed to read artwork: $e');
    }
  }

  static Stream<MediaStoreSong> getSongs() async* {
    try {
      final List result = await _channel.invokeMethod('getSongs');

      for (final value in result) {
        final map = Map<String, dynamic>.from(value);
        final song = MediaStoreSong.fromMap(map);
        yield song;
      }
    } catch (e) {
      throw Exception('Failed to get songs: $e');
    }
  }

  static Stream<MediaStoreSong> getAlbumSongs(String albumId) async* {
    try {
      final List result = await _channel.invokeMethod('getAlbumSongs', {"albumId": albumId});
      for (final value in result) {
        final map = Map<String, dynamic>.from(value);
        final song = MediaStoreSong.fromMap(map);
        yield song;
      }
    } catch (e) {
      throw Exception('Failed to get album songs: $e');
    }
  }

  static Stream<MediaStoreArtist> getArtists() async* {
    try {
      final List result = await _channel.invokeMethod('getArtists');

      for (final value in result) {
        final map = Map<String, dynamic>.from(value);
        final artist = MediaStoreArtist.fromMap(map);
        if (isEmptyValue(artist.name)) {
          continue;
        }
        yield artist;
      }
    } catch (e) {
      throw Exception('Failed to get artists: $e');
    }
  }

  static Stream<MediaStoreAlbum> getAlbums() async* {
    try {
      final List result = await _channel.invokeMethod('getAlbums');

      for (final value in result) {
        final map = Map<String, dynamic>.from(value);
        final album = MediaStoreAlbum.fromMap(map);
        if (isEmptyValue(album.artist?.name)) {
          continue;
        }
        yield album;
      }
    } catch (e) {
      throw Exception('Failed to get albums: $e');
    }
  }

  static Future<bool> checkPermission() async {
    try {
      final bool result = await _channel.invokeMethod('checkPermission');
      return result;
    } catch (e) {
      throw Exception('Failed to check permission: $e');
    }
  }

  static Future<bool> requestPermission() async {
    try {
      final bool result = await _channel.invokeMethod('requestPermission');
      return result;
    } catch (e) {
      throw Exception('Failed to request permission: $e');
    }
  }
}

class MediaStoreSong {
  final int id;
  final String name;
  final Duration duration;
  final Uri? artwork;

  final Uri path;
  final String mimeType;

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
  });

  factory MediaStoreSong.fromMap(Map<String, dynamic> map) {
    final artworkUri = (map['artwork'] as String?).let(Uri.parse);

    return MediaStoreSong(
      id: map['id'],
      name: map['name'],
      artist: switch (map['artist']) {
        final artist when MediaStorePlugin.isEmptyValue(artist) => null,
        final artist => MediaStoreArtist(id: map['artistId'], name: artist),
      },
      album: MediaStoreAlbum(
        id: map['albumId'],
        name: map['album'],
        artist: switch (map['albumArtist']) {
          String artist => MediaStoreArtist(id: map['albumId'], name: artist),
          _ => null,
        },
        artwork: artworkUri,
      ),
      albumTrack: map['albumTrack'],
      albumDisc: map['albumDisc'],
      mimeType: map['mimeType'],
      duration: Duration(milliseconds: map['duration']),
      path: Uri.parse(map['path']),
      artwork: artworkUri,
    );
  }

  int get albumHash => "$name/$albumDisc/$albumTrack".hashCode;
}

class MediaStoreArtist {
  final int id;
  final String name;

  MediaStoreArtist({required this.id, required this.name});

  factory MediaStoreArtist.fromMap(Map<String, dynamic> map) {
    return MediaStoreArtist(id: map['id'], name: map['name']);
  }
}

class MediaStoreAlbum {
  final int id;
  final String name;
  final Uri? artwork;
  final MediaStoreArtist? artist;

  MediaStoreAlbum({required this.id, required this.name, this.artist, this.artwork});

  factory MediaStoreAlbum.fromMap(Map<String, dynamic> map) {
    return MediaStoreAlbum(
      id: map['id'],
      name: map['name'],
      artist: switch (map['artist']) {
        final artist when MediaStorePlugin.isEmptyValue(artist) => null,
        final artist => MediaStoreArtist(id: map['artistId'], name: artist),
      },
      artwork: (map['artwork'] as String?).let(Uri.parse),
    );
  }
}
