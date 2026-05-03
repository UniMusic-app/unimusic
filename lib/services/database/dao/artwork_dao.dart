import "package:sqflite/sqflite.dart";
import "package:unimusic/services/database/cache.dart";
import "package:unimusic/services/database/objects.dart";
import "package:unimusic/services/database/tables.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class ArtworkDao {
  final Database _db;

  ArtworkDao(this._db);

  Future<void> insert(
    Artwork artwork, {
    required String mimeType,
    required ArtworkSize size,
    String? filePath,
  }) async {
    await _db.insert(Tables.artworks, {
      "id": artwork.id,
      "provider_id": artwork.providerId,
      "mime_type": mimeType,
      "size": size.toString(),
      "file_path": filePath,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ArtworkDatabaseItem?> get(String id, {ArtworkSize? size}) async {
    if (size != null) {
      final results = await _db.query(
        Tables.artworks,
        where: "id = ? AND size = ?",
        whereArgs: [id, size.toString()],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return ArtworkDatabaseItem.fromMap(results.first);
      }
    }

    // Fallback to any size variant, preferring larger size
    final results = await _db.query(
      Tables.artworks,
      where: "id = ?",
      whereArgs: [id],
      orderBy: """
      CASE size
          WHEN 'large' THEN 3
          WHEN 'medium' THEN 2
          WHEN 'small' THEN 1
      END DESC;
      """,
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ArtworkDatabaseItem.fromMap(results.first);
  }

  Future<List<ArtworkDatabaseItem>> getAll() async {
    final results = await _db.query(Tables.artworks);
    return results.map(ArtworkDatabaseItem.fromMap).toList();
  }

  Future<List<ArtworkDatabaseItem>> getAllSizes(String id) async {
    final results = await _db.query(
      Tables.artworks,
      where: "id = ?",
      whereArgs: [id],
    );
    return results.map(ArtworkDatabaseItem.fromMap).toList();
  }

  Future<void> update(
    String id, {
    required ArtworkSize size,
    required String mimeType,
    String? filePath,
  }) async {
    await _db.update(
      Tables.artworks,
      {"mime_type": mimeType, "file_path": filePath},
      where: "id = ? AND size = ?",
      whereArgs: [id, size.toString()],
    );
  }

  Future<void> delete(String id, {ArtworkSize? size}) async {
    if (size != null) {
      final artworkData = await get(id, size: size);
      if (artworkData != null) {
        await CacheHelper.deleteArtwork(id, artworkData.mimeType, size);
      }
      await _db.delete(
        Tables.artworks,
        where: "id = ? AND size = ?",
        whereArgs: [id, size.toString()],
      );
    } else {
      final artworkSizes = await getAllSizes(id);
      for (final artworkData in artworkSizes) {
        await CacheHelper.deleteArtwork(
          id,
          artworkData.mimeType,
          artworkData.size,
        );
      }
      await _db.delete(Tables.artworks, where: "id = ?", whereArgs: [id]);
    }
  }
}
