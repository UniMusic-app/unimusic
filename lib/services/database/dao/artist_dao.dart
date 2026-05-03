import "package:sqflite/sqflite.dart";
import "package:unimusic/services/database/objects.dart";
import "package:unimusic/services/database/tables.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class ArtistDao {
  final Database _db;

  ArtistDao(this._db);

  Future<void> insert(Artist artist) async {
    await _db.insert(Tables.artists, {
      "id": artist.id,
      "provider_id": artist.providerId,
      "name": artist.name,
      "artwork_id": artist.artwork?.id,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ArtistDatabaseItem?> get(String id) async {
    final results = await _db.query(
      Tables.artists,
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ArtistDatabaseItem.fromMap(results.first);
  }

  Future<List<ArtistDatabaseItem>> getAll() async {
    final results = await _db.query(Tables.artists);
    return results.map(ArtistDatabaseItem.fromMap).toList();
  }

  Future<List<ArtistDatabaseItem>> getByProvider(String providerId) async {
    final results = await _db.query(
      Tables.artists,
      where: "provider_id = ?",
      whereArgs: [providerId],
    );
    return results.map(ArtistDatabaseItem.fromMap).toList();
  }

  Future<void> update(Artist artist) async {
    await _db.update(
      Tables.artists,
      {
        "provider_id": artist.providerId,
        "name": artist.name,
        "artwork_id": artist.artwork?.id,
      },
      where: "id = ?",
      whereArgs: [artist.id],
    );
  }

  Future<void> delete(String id) async {
    await _db.delete(Tables.artists, where: "id = ?", whereArgs: [id]);
  }

  Future<List<ArtistDatabaseItem>> search(String query) async {
    final results = await _db.query(
      Tables.artists,
      where: "name LIKE ?",
      whereArgs: ["%$query%"],
    );
    return results.map(ArtistDatabaseItem.fromMap).toList();
  }
}
