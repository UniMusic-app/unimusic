import "package:sqflite/sqflite.dart";
import "package:unimusic/services/database/objects.dart";
import "package:unimusic/services/database/tables.dart";

class FavouriteDao {
  final Database _db;

  FavouriteDao(this._db);

  Future<void> setSong(String id, bool favourite) async {
    await _db.update(
      Tables.songs,
      {"favourite": favourite ? 1 : 0},
      where: "id = ?",
      whereArgs: [id],
    );
  }

  Future<void> setAlbum(String id, bool favourite) async {
    await _db.update(
      Tables.albums,
      {"favourite": favourite ? 1 : 0},
      where: "id = ?",
      whereArgs: [id],
    );
  }

  Future<void> setArtist(String id, bool favourite) async {
    await _db.update(
      Tables.artists,
      {"favourite": favourite ? 1 : 0},
      where: "id = ?",
      whereArgs: [id],
    );
  }

  Future<List<SongDatabaseItem>> getSongs() async {
    final results = await _db.query(Tables.songs, where: "favourite = 1");
    return results.map(SongDatabaseItem.fromMap).toList();
  }

  Future<List<AlbumDatabaseItem>> getAlbums() async {
    final results = await _db.query(Tables.albums, where: "favourite = 1");
    return results.map(AlbumDatabaseItem.fromMap).toList();
  }

  Future<List<ArtistDatabaseItem>> getArtists() async {
    final results = await _db.query(Tables.artists, where: "favourite = 1");
    return results.map(ArtistDatabaseItem.fromMap).toList();
  }

  /// Returns all favourited songs and albums associated with the given artist.
  Future<({List<SongDatabaseItem> songs, List<AlbumDatabaseItem> albums})>
  getByArtist(String artistId) async {
    final songResults = await _db.rawQuery(
      """
      SELECT s.* FROM ${Tables.songs} s
      JOIN ${Tables.songArtists} sa ON s.id = sa.song_id
      WHERE sa.artist_id = ? AND s.favourite = 1
      """,
      [artistId],
    );
    final albumResults = await _db.rawQuery(
      """
      SELECT a.* FROM ${Tables.albums} a
      JOIN ${Tables.albumArtists} aa ON a.id = aa.album_id
      WHERE aa.artist_id = ? AND a.favourite = 1
      """,
      [artistId],
    );
    return (
      songs: songResults.map(SongDatabaseItem.fromMap).toList(),
      albums: albumResults.map(AlbumDatabaseItem.fromMap).toList(),
    );
  }
}
