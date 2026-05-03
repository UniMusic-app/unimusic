import "package:sqflite/sqflite.dart";
import "package:unimusic/services/database/objects.dart";
import "package:unimusic/services/database/tables.dart";

class RecentSearchDao {
  final Database _db;

  RecentSearchDao(this._db);

  Future<void> insert(String id, String type) async {
    await _db.insert(Tables.recentSearches, {
      "id": id,
      "type": type,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<RecentSearchDatabaseItem>> getAll() async {
    final results = await _db.query(
      Tables.recentSearches,
      orderBy: "ROWID DESC",
    );
    return results.map(RecentSearchDatabaseItem.fromMap).toList();
  }

  Future<void> delete(String id) async {
    await _db.delete(Tables.recentSearches, where: "id = ?", whereArgs: [id]);
  }

  Future<void> clear() async {
    await _db.delete(Tables.recentSearches);
  }
}
