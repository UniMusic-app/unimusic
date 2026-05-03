import "package:sqflite/sqflite.dart";
import "package:unimusic/services/database/objects.dart";
import "package:unimusic/services/database/tables.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class SongDao {
  final Database _db;

  SongDao(this._db);

  Future<void> insert(Song song) async {
    await _db.transaction((txn) async {
      await txn.insert(Tables.songs, {
        "id": song.id,
        "provider_id": song.providerId,
        "name": song.name,
        "duration": song.duration.inMilliseconds,
        "album": song.album,
        "artwork_id": song.artwork?.id,
        "file_path": song.filePath,
        "disc_number": song.discNumber,
        "track_number": song.trackNumber,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      for (final artist in song.artists) {
        await txn.insert(Tables.songArtists, {
          "song_id": song.id,
          "artist_id": artist.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<SongDatabaseItem?> get(String id) async {
    final results = await _db.query(
      Tables.songs,
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SongDatabaseItem.fromMap(results.first);
  }

  Future<List<SongDatabaseItem>> getAll() async {
    final results = await _db.query(Tables.songs);
    return results.map(SongDatabaseItem.fromMap).toList();
  }

  Future<List<SongDatabaseItem>> getByProvider(String providerId) async {
    final results = await _db.query(
      Tables.songs,
      where: "provider_id = ?",
      whereArgs: [providerId],
    );
    return results.map(SongDatabaseItem.fromMap).toList();
  }

  Future<List<SongDatabaseItem>> getByArtist(String artistId) async {
    final results = await _db.rawQuery(
      """
      SELECT s.* FROM ${Tables.songs} s
      JOIN ${Tables.songArtists} sa ON s.id = sa.song_id
      WHERE sa.artist_id = ?
      """,
      [artistId],
    );
    return results.map(SongDatabaseItem.fromMap).toList();
  }

  Future<List<SongDatabaseItem>> getByAlbum(String album) async {
    final results = await _db.query(
      Tables.songs,
      where: "album = ?",
      whereArgs: [album],
    );
    return results.map(SongDatabaseItem.fromMap).toList();
  }

  Future<List<ArtistDatabaseItem>> getArtists(String songId) async {
    final results = await _db.rawQuery(
      """
      SELECT a.* FROM ${Tables.artists} a
      JOIN ${Tables.songArtists} sa ON a.id = sa.artist_id
      WHERE sa.song_id = ?
      """,
      [songId],
    );
    return results.map(ArtistDatabaseItem.fromMap).toList();
  }

  Future<List<AlbumDatabaseItem>> getAlbums(String songId) async {
    final results = await _db.rawQuery(
      """
      SELECT a.* FROM ${Tables.albums} a
      JOIN ${Tables.albumSongs} als ON a.id = als.album_id
      WHERE als.song_id = ?
      """,
      [songId],
    );
    return results.map(AlbumDatabaseItem.fromMap).toList();
  }

  Future<void> update(Song song) async {
    await _db.transaction((txn) async {
      await txn.update(
        Tables.songs,
        {
          "provider_id": song.providerId,
          "name": song.name,
          "duration": song.duration.inMilliseconds,
          "album": song.album,
          "artwork_id": song.artwork?.id,
        },
        where: "id = ?",
        whereArgs: [song.id],
      );

      await txn.delete(
        Tables.songArtists,
        where: "song_id = ?",
        whereArgs: [song.id],
      );

      for (final artist in song.artists) {
        await txn.insert(Tables.songArtists, {
          "song_id": song.id,
          "artist_id": artist.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> delete(String id) async {
    await _db.transaction((txn) async {
      await txn.delete(
        Tables.albumSongs,
        where: "song_id = ?",
        whereArgs: [id],
      );
      await txn.delete(Tables.songs, where: "id = ?", whereArgs: [id]);
    });
  }

  Future<List<SongDatabaseItem>> search(String query) async {
    final results = await _db.query(
      Tables.songs,
      where: "name LIKE ? OR album LIKE ?",
      whereArgs: ["%$query%", "%$query%"],
    );
    return results.map(SongDatabaseItem.fromMap).toList();
  }
}
