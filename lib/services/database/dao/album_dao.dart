import "package:sqflite/sqflite.dart";
import "package:unimusic/services/database/objects.dart";
import "package:unimusic/services/database/tables.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class AlbumDao {
  final Database _db;

  AlbumDao(this._db);

  Future<void> insert(Album album) async {
    await _db.transaction((txn) async {
      await txn.insert(Tables.albums, {
        "id": album.id,
        "provider_id": album.providerId,
        "name": album.name,
        "artwork_id": album.artwork?.id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      for (final artist in album.artists) {
        await txn.insert(Tables.albumArtists, {
          "album_id": album.id,
          "artist_id": artist.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<AlbumDatabaseItem?> get(String id) async {
    final results = await _db.query(
      Tables.albums,
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return AlbumDatabaseItem.fromMap(results.first);
  }

  Future<List<AlbumDatabaseItem>> getAll() async {
    final results = await _db.query(Tables.albums);
    return results.map(AlbumDatabaseItem.fromMap).toList();
  }

  Future<List<AlbumDatabaseItem>> getByProvider(String providerId) async {
    final results = await _db.query(
      Tables.albums,
      where: "provider_id = ?",
      whereArgs: [providerId],
    );
    return results.map(AlbumDatabaseItem.fromMap).toList();
  }

  Future<List<AlbumDatabaseItem>> getByArtist(String artistId) async {
    final results = await _db.rawQuery(
      """
      SELECT a.* FROM ${Tables.albums} a
      JOIN ${Tables.albumArtists} aa ON a.id = aa.album_id
      WHERE aa.artist_id = ?
      """,
      [artistId],
    );
    return results.map(AlbumDatabaseItem.fromMap).toList();
  }

  Future<List<ArtistDatabaseItem>> getArtists(String albumId) async {
    final results = await _db.rawQuery(
      """
      SELECT a.* FROM ${Tables.artists} a
      JOIN ${Tables.albumArtists} aa ON a.id = aa.artist_id
      WHERE aa.album_id = ?
      """,
      [albumId],
    );
    return results.map(ArtistDatabaseItem.fromMap).toList();
  }

  Future<List<SongDatabaseItem>> getSongs(String albumId) async {
    final results = await _db.rawQuery(
      """
      SELECT s.* FROM ${Tables.songs} s
      JOIN ${Tables.albumSongs} als ON s.id = als.song_id
      WHERE als.album_id = ?
      """,
      [albumId],
    );
    return results.map(SongDatabaseItem.fromMap).toList();
  }

  Future<void> insertSong(String albumId, String songId) async {
    await _db.insert(Tables.albumSongs, {
      "album_id": albumId,
      "song_id": songId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSong(String albumId, String songId) async {
    await _db.delete(
      Tables.albumSongs,
      where: "album_id = ? AND song_id = ?",
      whereArgs: [albumId, songId],
    );
  }

  Future<void> deleteSongs(String albumId) async {
    await _db.delete(
      Tables.albumSongs,
      where: "album_id = ?",
      whereArgs: [albumId],
    );
  }

  Future<void> update(Album album) async {
    await _db.transaction((txn) async {
      await txn.update(
        Tables.albums,
        {
          "provider_id": album.providerId,
          "name": album.name,
          "artwork_id": album.artwork?.id,
        },
        where: "id = ?",
        whereArgs: [album.id],
      );

      await txn.delete(
        Tables.albumArtists,
        where: "album_id = ?",
        whereArgs: [album.id],
      );

      for (final artist in album.artists) {
        await txn.insert(Tables.albumArtists, {
          "album_id": album.id,
          "artist_id": artist.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> delete(String id) async {
    await _db.transaction((txn) async {
      await txn.delete(
        Tables.albumSongs,
        where: "album_id = ?",
        whereArgs: [id],
      );
      await txn.delete(Tables.albums, where: "id = ?", whereArgs: [id]);
    });
  }

  Future<List<AlbumDatabaseItem>> search(String query) async {
    final results = await _db.query(
      Tables.albums,
      where: "name LIKE ?",
      whereArgs: ["%$query%"],
    );
    return results.map(AlbumDatabaseItem.fromMap).toList();
  }
}
