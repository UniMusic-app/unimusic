import "dart:io";
import "package:flutter/foundation.dart";
import "package:mime/mime.dart";
import "package:path/path.dart" as path;
import "package:crypto/crypto.dart";
import "package:path_provider/path_provider.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class CacheHelper {
  static String? _cacheDirectory;
  static Future<String> getCacheDirectory() async {
    if (_cacheDirectory != null) {
      return _cacheDirectory!;
    }

    final directory = await getApplicationCacheDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _cacheDirectory = directory.path;
    return _cacheDirectory!;
  }

  static String? _artworkCacheDirectory;
  static Future<String> getArtworkCacheDirectory() async {
    if (_artworkCacheDirectory != null) {
      return _artworkCacheDirectory!;
    }

    final cacheDir = await getCacheDirectory();
    final directory = Directory(path.join(cacheDir, "artwork"));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _artworkCacheDirectory = directory.path;
    return _artworkCacheDirectory!;
  }

  static String _generateFileName(
    String id,
    String mimeType,
    ArtworkSize size,
  ) {
    // Create a safe filename from the ID
    final hash = sha256.convert(id.codeUnits).toString();
    final extension = extensionFromMime(mimeType);
    return "$hash-$size.$extension";
  }

  static Future<String> saveArtwork(
    String id, {
    required Uint8List data,
    required String mimeType,
    required ArtworkSize size,
  }) async {
    final artworkDir = await getArtworkCacheDirectory();
    final fileName = _generateFileName(id, mimeType, size);
    final filePath = path.join(artworkDir, fileName);
    final file = File(filePath);
    await file.writeAsBytes(data);
    return filePath;
  }

  static Future<File?> getArtworkFile(
    String id,
    String mimeType,
    ArtworkSize size,
  ) async {
    final artworkDir = await getArtworkCacheDirectory();
    final fileName = _generateFileName(id, mimeType, size);
    final filePath = path.join(artworkDir, fileName);
    final file = File(filePath);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  static Future<bool> hasArtwork(
    String id,
    String mimeType,
    ArtworkSize size,
  ) async {
    final file = await getArtworkFile(id, mimeType, size);
    return file != null;
  }

  static Future<void> deleteArtwork(
    String id,
    String mimeType,
    ArtworkSize size,
  ) async {
    final file = await getArtworkFile(id, mimeType, size);
    if (file != null && await file.exists()) {
      await file.delete();
      debugPrint("Deleted artwork: $id");
    }
  }

  static Future<void> deleteAllArtworkSizes(String id, String mimeType) async {
    final hash = sha256.convert(id.codeUnits).toString();
    final extension = extensionFromMime(mimeType) ?? "jpg";

    await for (final entity in getArtworkFiles()) {
      if (entity is! File) {
        continue;
      }

      final fileName = entity.uri.pathSegments.last;
      if (fileName.startsWith(hash) && fileName.endsWith(".$extension")) {
        await entity.delete();
        debugPrint("Deleted artwork variant: $fileName");
      }
    }
  }

  static Future<void> clearArtworkCache() async {
    final artworkDir = await getArtworkCacheDirectory();
    final directory = Directory(artworkDir);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
      debugPrint("Cleared artwork cache");
    }
  }

  static Future<int> getArtworkCacheSize() async {
    int totalSize = 0;
    await for (final entity in getArtworkFiles()) {
      if (entity is File) {
        final stat = await entity.stat();
        totalSize += stat.size;
      }
    }
    return totalSize;
  }

  static Stream<FileSystemEntity> getArtworkFiles() async* {
    final artworkDir = await getArtworkCacheDirectory();
    final directory = Directory(artworkDir);
    if (!await directory.exists()) {
      return;
    }
    yield* directory.list();
  }
}
