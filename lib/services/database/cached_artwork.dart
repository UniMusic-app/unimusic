import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unimusic/services/database/cache.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/services/database/database.dart';
import 'package:dio/dio.dart';
import 'dart:ui' as ui;

final dio = Dio(
  BaseOptions(
    responseType: ResponseType.bytes,
    headers: {'User-Agent': 'UniMusic/1.0'},
  ),
);

abstract class CachedArtwork extends Artwork {
  static final Map<String, Completer<String?>> _downloadingArtworks = {};
  static final Map<String, String?> _cachedPaths = {};

  const CachedArtwork({required super.id, required super.providerId});

  String getMimeType();

  @override
  ImageProvider? getImage(ArtworkSize size) {
    return CachedArtworkImageProvider(artwork: this, size: size);
  }

  /// Download and cache the artwork with synchronization to prevent concurrent downloads
  Future<String?> _downloadAndCache(ArtworkSize size) async {
    final mimeType = getMimeType();
    final cacheKey = '$id:$mimeType:$size';

    final cachedPath = _cachedPaths[cacheKey];
    if (cachedPath != null) {
      return cachedPath;
    }

    final cachedArtwork = await CacheHelper.getArtworkFile(id, mimeType, size);
    if (cachedArtwork != null) {
      final path = cachedArtwork.path;
      _cachedPaths[cacheKey] = path;
      return path;
    }

    if (_downloadingArtworks.containsKey(cacheKey)) {
      return await _downloadingArtworks[cacheKey]!.future;
    }

    final uri = getImageUri(size);
    if (uri == null) {
      debugPrint("Received empty uri");
      _cachedPaths[cacheKey] = null;
      return null;
    }

    final completer = Completer<String?>();
    _downloadingArtworks[cacheKey] = completer;

    try {
      debugPrint("Downloading artwork: $uri");
      final response = await dio.getUri<Uint8List>(uri);

      if (response.data == null) {
        completer.complete(null);
        return null;
      }

      final filePath = await CacheHelper.saveArtwork(
        id,
        data: response.data!,
        mimeType: mimeType,
        size: size,
      );

      try {
        final existingArtwork = await DatabaseHelper.getArtwork(id, size: size);
        if (existingArtwork != null) {
          await DatabaseHelper.updateArtwork(
            id,
            mimeType: mimeType,
            filePath: filePath,
            size: size,
          );
        } else {
          await DatabaseHelper.insertArtwork(
            this,
            filePath: filePath,
            mimeType: mimeType,
            size: size,
          );
        }
      } catch (dbError) {
        // Continue even if database update fails - we still have the cached file
        debugPrint("Database error for artwork $id: $dbError");
      }

      _cachedPaths[cacheKey] = filePath;
      completer.complete(filePath);
      return filePath;
    } catch (error) {
      debugPrint("Failed to download artwork $id: $error");
      completer.complete(null);
      return null;
    } finally {
      _downloadingArtworks.remove(cacheKey);
    }
  }
}

class CachedArtworkImageProvider
    extends ImageProvider<CachedArtworkImageProvider> {
  final CachedArtwork artwork;
  final ArtworkSize size;
  final int? quality;

  const CachedArtworkImageProvider({
    required this.artwork,
    required this.size,
    this.quality,
  });

  @override
  Future<CachedArtworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    CachedArtworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'CachedArtwork(${key.artwork.id})',
    );
  }

  Future<ui.Codec> _loadAsync(
    CachedArtworkImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final filePath = await key.artwork._downloadAndCache(size);

      if (filePath == null) {
        throw Exception("Artwork ${key.artwork.id} doesn't exist");
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception("File $filePath doesn't exist");
      }

      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        return await decode(buffer);
      }
    } catch (downloadError) {
      debugPrint("Download error for ${key.artwork.id}: $downloadError");
    }

    try {
      debugPrint(
        "Fallback: loading artwork ${key.artwork.id} directly from network",
      );

      final uri = key.artwork.getImageUri(size);

      final dio = Dio();
      final response = await dio.get<Uint8List>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'User-Agent': 'UniMusic/1.0'},
        ),
      );

      if (response.data != null && response.data!.isNotEmpty) {
        final buffer = await ui.ImmutableBuffer.fromUint8List(response.data!);
        return await decode(buffer);
      }
    } catch (networkError) {
      debugPrint("Network fallback error for ${key.artwork.id}: $networkError");
    }

    throw Exception('All artwork loading methods failed for ${key.artwork.id}');
  }
}
