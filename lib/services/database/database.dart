import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/services/database/cache.dart';
import 'package:unimusic/services/database/objects.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static late final Database db;

  DatabaseHelper._internal();
  static late final DatabaseHelper _instance;
  factory DatabaseHelper() {
    return _instance;
  }

  static Future<String> getDatabaseDirectory() async {
    final directory = await getApplicationSupportDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static Future<void> instantiate() async {
    final databaseDirectory = await getDatabaseDirectory();
    final databasePath = path.join(databaseDirectory, "unimusic.db");
    debugPrint("DB Path: $databasePath");

    db = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute("""
          CREATE TABLE recent_searches (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL
          )
        """);

        await db.execute("""
          CREATE TABLE artwork_items (
            id TEXT NOT NULL,
            provider_id TEXT NOT NULL,
            mime_type TEXT NOT NULL,
            size TEXT NOT NULL,
            file_path TEXT,
            PRIMARY KEY(id, size)
          )
        """);

        await db.execute("""
          CREATE TABLE artist_items (
            id TEXT PRIMARY KEY,
            provider_id TEXT NOT NULL,
            name TEXT NOT NULL,
            artwork_id TEXT,
            FOREIGN KEY(artwork_id) REFERENCES artwork_items(id) ON DELETE SET NULL
          )
        """);

        await db.execute("""
          CREATE TABLE album_items (
            id TEXT PRIMARY KEY,
            provider_id TEXT NOT NULL,
            name TEXT NOT NULL,
            artwork_id TEXT,
            FOREIGN KEY(artwork_id) REFERENCES artwork_items(id) ON DELETE SET NULL
          )
        """);

        await db.execute("""
          CREATE TABLE song_items (
            id TEXT PRIMARY KEY,
            provider_id TEXT NOT NULL,
            name TEXT NOT NULL,
            duration INTEGER NOT NULL,
            album TEXT,
            artwork_id TEXT,
            FOREIGN KEY(artwork_id) REFERENCES artwork_items(id) ON DELETE SET NULL
          )
        """);

        await db.execute("""
          CREATE TABLE album_artists (
            album_id TEXT NOT NULL,
            artist_id TEXT NOT NULL,
            PRIMARY KEY(album_id, artist_id),
            FOREIGN KEY(album_id) REFERENCES album_items(id) ON DELETE CASCADE,
            FOREIGN KEY(artist_id) REFERENCES artist_items(id) ON DELETE CASCADE
          )
        """);

        await db.execute("""
          CREATE TABLE song_artists (
            song_id TEXT NOT NULL,
            artist_id TEXT NOT NULL,
            PRIMARY KEY(song_id, artist_id),
            FOREIGN KEY(song_id) REFERENCES song_items(id) ON DELETE CASCADE,
            FOREIGN KEY(artist_id) REFERENCES artist_items(id) ON DELETE CASCADE
          )
        """);

        await db.execute("""
          CREATE TABLE album_songs (
            album_id TEXT NOT NULL,
            song_id TEXT NOT NULL,
            PRIMARY KEY(album_id, song_id),
            FOREIGN KEY(album_id) REFERENCES album_items(id) ON DELETE CASCADE,
            FOREIGN KEY(song_id) REFERENCES song_items(id) ON DELETE CASCADE
          )
        """);
      },
    );

    _instance = DatabaseHelper._internal();
  }

  // ARTWORK METHODS
  static Future<void> insertArtwork(
    Artwork artwork, {
    required String mimeType,
    required ArtworkSize size,
    String? filePath,
  }) async {
    await db.insert("artwork_items", {
      "id": artwork.id,
      "provider_id": artwork.providerId,
      "mime_type": mimeType,
      "size": size.toString(),
      "file_path": filePath,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<ArtworkDatabaseItem?> getArtwork(String id, {ArtworkSize? size}) async {
    if (size != null) {
      // Get specific size
      final results = await db.query(
        "artwork_items",
        where: "id = ? AND size = ?",
        whereArgs: [id, size.toString()],
        limit: 1,
      );

      if (results.isNotEmpty) {
        return ArtworkDatabaseItem.fromMap(results.first);
      }
    }

    // Fallback to any size variant, preferring larger size
    final results = await db.query(
      "artwork_items",
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
    if (results.isEmpty) {
      return null;
    }
    return ArtworkDatabaseItem.fromMap(results.first);
  }

  static Future<List<ArtworkDatabaseItem>> getAllArtwork() async {
    final results = await db.query("artwork_items");
    return results.map(ArtworkDatabaseItem.fromMap).toList();
  }

  static Future<List<ArtworkDatabaseItem>> getAllArtworkSizes(String id) async {
    final results = await db.query("artwork_items", where: "id = ?", whereArgs: [id]);
    return results.map(ArtworkDatabaseItem.fromMap).toList();
  }

  static Future<void> updateArtwork(
    String id, {
    required ArtworkSize size,
    required String mimeType,
    String? filePath,
  }) async {
    await db.update(
      "artwork_items",
      {"mime_type": mimeType, "file_path": filePath},
      where: "id = ? AND size = ?",
      whereArgs: [id, size.toString()],
    );
  }

  static Future<void> deleteArtwork(String id, {ArtworkSize? size}) async {
    if (size != null) {
      // Delete specific size
      final artworkData = await getArtwork(id, size: size);
      if (artworkData != null) {
        await CacheHelper.deleteArtwork(id, artworkData.mimeType, size);
      }

      await db.delete(
        "artwork_items",
        where: "id = ? AND size = ?",
        whereArgs: [id, size.toString()],
      );
    } else {
      // Delete all sizes
      final artworkSizes = await getAllArtworkSizes(id);
      for (final artworkData in artworkSizes) {
        final mimeType = artworkData.mimeType;
        final size = artworkData.size;
        await CacheHelper.deleteArtwork(id, mimeType, size);
      }
      await db.delete("artwork_items", where: "id = ?", whereArgs: [id]);
    }
  }

  // ARTIST METHODS
  static Future<void> insertArtist(Artist artist) async {
    await db.transaction((txn) async {
      await txn.insert("artist_items", {
        "id": artist.id,
        "provider_id": artist.providerId,
        "name": artist.name,
        "artwork_id": artist.artwork?.id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  static Future<ArtistDatabaseItem?> getArtist(String id) async {
    final List<Map<String, dynamic>> results = await db.query(
      "artist_items",
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }
    return ArtistDatabaseItem.fromMap(results.first);
  }

  static Future<List<ArtistDatabaseItem>> getAllArtists() async {
    final results = await db.query("artist_items");
    return results.map(ArtistDatabaseItem.fromMap).toList();
  }

  static Future<List<ArtistDatabaseItem>> getArtistsByProvider(String providerId) async {
    final results = await db.query(
      "artist_items",
      where: "provider_id = ?",
      whereArgs: [providerId],
    );
    return results.map(ArtistDatabaseItem.fromMap).toList();
  }

  static Future<void> updateArtist(Artist artist) async {
    await db.transaction((txn) async {
      await txn.update(
        "artist_items",
        {"provider_id": artist.providerId, "name": artist.name, "artwork_id": artist.artwork?.id},
        where: "id = ?",
        whereArgs: [artist.id],
      );
    });
  }

  static Future<void> deleteArtist(String id) async {
    await db.delete("artist_items", where: "id = ?", whereArgs: [id]);
  }

  // ALBUM METHODS
  static Future<void> insertAlbum(Album album) async {
    await db.transaction((txn) async {
      await txn.insert("album_items", {
        "id": album.id,
        "provider_id": album.providerId,
        "name": album.name,
        "artwork_id": album.artwork?.id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Insert album-artist relationships
      for (final artist in album.artists) {
        await txn.insert("album_artists", {
          "album_id": album.id,
          "artist_id": artist.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<AlbumDatabaseItem?> getAlbum(String id) async {
    final List<Map<String, dynamic>> results = await db.query(
      "album_items",
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }
    return AlbumDatabaseItem.fromMap(results.first);
  }

  static Future<List<AlbumDatabaseItem>> getAllAlbums() async {
    final results = await db.query("album_items");
    return results.map(AlbumDatabaseItem.fromMap).toList();
  }

  static Future<List<AlbumDatabaseItem>> getAlbumsByProvider(String providerId) async {
    final results = await db.query(
      "album_items",
      where: "provider_id = ?",
      whereArgs: [providerId],
    );
    return results.map(AlbumDatabaseItem.fromMap).toList();
  }

  static Future<List<AlbumDatabaseItem>> getAlbumsByArtist(String artistId) async {
    final results = await db.rawQuery(
      """
      SELECT a.* FROM album_items a
      JOIN album_artists aa ON a.id = aa.album_id
      WHERE aa.artist_id = ?
      """,
      [artistId],
    );
    return results.map(AlbumDatabaseItem.fromMap).toList();
  }

  static Future<List<ArtistDatabaseItem>> getAlbumArtists(String albumId) async {
    final results = await db.rawQuery(
      """
      SELECT a.* FROM artist_items a
      JOIN album_artists aa ON a.id = aa.artist_id
      WHERE aa.album_id = ?
      """,
      [albumId],
    );
    return results.map(ArtistDatabaseItem.fromMap).toList();
  }

  static Future<void> updateAlbum(Album album) async {
    await db.transaction((txn) async {
      await txn.update(
        "album_items",
        {"provider_id": album.providerId, "name": album.name, "artwork_id": album.artwork?.id},
        where: "id = ?",
        whereArgs: [album.id],
      );

      // Delete existing album-artist relationships
      await txn.delete("album_artists", where: "album_id = ?", whereArgs: [album.id]);

      // Insert new album-artist relationships
      for (final artist in album.artists) {
        await txn.insert("album_artists", {
          "album_id": album.id,
          "artist_id": artist.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<void> deleteAlbum(String id) async {
    await db.transaction((txn) async {
      // Delete album-song relationships first
      await txn.delete("album_songs", where: "album_id = ?", whereArgs: [id]);
      // Delete the album
      await txn.delete("album_items", where: "id = ?", whereArgs: [id]);
    });
  }

  // SONG METHODS
  static Future<void> insertSong(Song song) async {
    await db.transaction((txn) async {
      await txn.insert("song_items", {
        "id": song.id,
        "provider_id": song.providerId,
        "name": song.name,
        "duration": song.duration.inMilliseconds,
        "album": song.album,
        "artwork_id": song.artwork?.id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Insert song-artist relationships
      for (final artist in song.artists) {
        await txn.insert("song_artists", {
          "song_id": song.id,
          "artist_id": artist.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<SongDatabaseItem?> getSong(String id) async {
    final List<Map<String, dynamic>> results = await db.query(
      "song_items",
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }
    return SongDatabaseItem.fromMap(results.first);
  }

  static Future<List<SongDatabaseItem>> getAllSongs() async {
    final results = await db.query("song_items");
    return results.map(SongDatabaseItem.fromMap).toList();
  }

  static Future<List<SongDatabaseItem>> getSongsByProvider(String providerId) async {
    final results = await db.query("song_items", where: "provider_id = ?", whereArgs: [providerId]);
    return results.map(SongDatabaseItem.fromMap).toList();
  }

  static Future<List<SongDatabaseItem>> getSongsByArtist(String artistId) async {
    final results = await db.rawQuery(
      """
      SELECT s.* FROM song_items s
      JOIN song_artists sa ON s.id = sa.song_id
      WHERE sa.artist_id = ?
      """,
      [artistId],
    );
    return results.map(SongDatabaseItem.fromMap).toList();
  }

  static Future<List<ArtistDatabaseItem>> getSongArtists(String songId) async {
    final results = await db.rawQuery(
      """
      SELECT a.* FROM artist_items a
      JOIN song_artists sa ON a.id = sa.artist_id
      WHERE sa.song_id = ?
      """,
      [songId],
    );
    return results.map(ArtistDatabaseItem.fromMap).toList();
  }

  static Future<List<SongDatabaseItem>> getSongsByAlbum(String album) async {
    final results = await db.query("song_items", where: "album = ?", whereArgs: [album]);
    return results.map(SongDatabaseItem.fromMap).toList();
  }

  static Future<List<SongDatabaseItem>> getSongsByAlbumId(String albumId) async {
    final results = await db.rawQuery(
      """
      SELECT s.* FROM song_items s
      JOIN album_songs als ON s.id = als.song_id
      WHERE als.album_id = ?
      """,
      [albumId],
    );
    return results.map(SongDatabaseItem.fromMap).toList();
  }

  static Future<List<AlbumDatabaseItem>> getSongAlbums(String songId) async {
    final results = await db.rawQuery(
      """
      SELECT a.* FROM album_items a
      JOIN album_songs als ON a.id = als.album_id
      WHERE als.song_id = ?
      """,
      [songId],
    );
    return results.map(AlbumDatabaseItem.fromMap).toList();
  }

  // ALBUM-SONG RELATIONSHIP METHODS
  static Future<void> insertAlbumSong(String albumId, String songId) async {
    await db.insert("album_songs", {
      "album_id": albumId,
      "song_id": songId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteAlbumSong(String albumId, String songId) async {
    await db.delete(
      "album_songs",
      where: "album_id = ? AND song_id = ?",
      whereArgs: [albumId, songId],
    );
  }

  static Future<void> deleteAlbumSongs(String albumId) async {
    await db.delete("album_songs", where: "album_id = ?", whereArgs: [albumId]);
  }

  static Future<void> updateSong(Song song) async {
    await db.transaction((txn) async {
      await txn.update(
        "song_items",
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

      // Delete existing song-artist relationships
      await txn.delete("song_artists", where: "song_id = ?", whereArgs: [song.id]);

      // Insert new song-artist relationships
      for (final artist in song.artists) {
        await txn.insert("song_artists", {
          "song_id": song.id,
          "artist_id": artist.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<void> deleteSong(String id) async {
    await db.transaction((txn) async {
      // Delete album-song relationships first
      await txn.delete("album_songs", where: "song_id = ?", whereArgs: [id]);
      // Delete the song
      await txn.delete("song_items", where: "id = ?", whereArgs: [id]);
    });
  }

  // RECENT SEARCHES METHODS
  static Future<void> insertRecentSearch(String id, String type) async {
    await db.insert("recent_searches", {
      "id": id,
      "type": type,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<RecentSearchDatabaseItem>> getRecentSearches() async {
    final results = await db.query("recent_searches", orderBy: "ROWID DESC");
    return results.map(RecentSearchDatabaseItem.fromMap).toList();
  }

  static Future<void> deleteRecentSearch(String id) async {
    await db.delete("recent_searches", where: "id = ?", whereArgs: [id]);
  }

  static Future<void> clearRecentSearches() async {
    await db.delete("recent_searches");
  }

  // UTILITY METHODS
  static Future<void> clearAllData() async {
    // Clear all cached artwork files before deleting database records
    await CacheHelper.clearArtworkCache();

    await db.transaction((txn) async {
      await txn.delete("song_artists");
      await txn.delete("album_artists");
      await txn.delete("album_songs");
      await txn.delete("song_items");
      await txn.delete("album_items");
      await txn.delete("artist_items");
      await txn.delete("artwork_items");
      await txn.delete("recent_searches");
    });
  }

  static Future<DatabaseStatsDatabaseItem> getDatabaseStats() async {
    final artworkCount = await db.rawQuery("SELECT COUNT(*) as count FROM artwork_items");
    final artistCount = await db.rawQuery("SELECT COUNT(*) as count FROM artist_items");
    final albumCount = await db.rawQuery("SELECT COUNT(*) as count FROM album_items");
    final songCount = await db.rawQuery("SELECT COUNT(*) as count FROM song_items");
    final searchCount = await db.rawQuery("SELECT COUNT(*) as count FROM recent_searches");

    return DatabaseStatsDatabaseItem(
      artwork: artworkCount.first['count'] as int,
      artists: artistCount.first['count'] as int,
      albums: albumCount.first['count'] as int,
      songs: songCount.first['count'] as int,
      recentSearches: searchCount.first['count'] as int,
    );
  }

  static Future<CacheStatsDatabaseItem> getCacheStats() async {
    // Get artwork cache size and file count
    final cacheSize = await CacheHelper.getArtworkCacheSize();
    final cacheFiles = await CacheHelper.getArtworkFiles().toList();
    final cacheDirectory = await CacheHelper.getCacheDirectory();

    return CacheStatsDatabaseItem(
      artworkCacheSizeBytes: cacheSize,
      artworkCacheFiles: cacheFiles.length,
      artworkCacheSizeMb: (cacheSize / (1024 * 1024)).toStringAsFixed(2),
      cacheDirectory: cacheDirectory,
    );
  }

  // SEARCH METHODS
  static Future<List<SongDatabaseItem>> searchSongs(String query) async {
    final results = await db.query(
      "song_items",
      where: "name LIKE ? OR album LIKE ?",
      whereArgs: ["%$query%", "%$query%"],
    );
    return results.map(SongDatabaseItem.fromMap).toList();
  }

  static Future<List<AlbumDatabaseItem>> searchAlbums(String query) async {
    final results = await db.query("album_items", where: "name LIKE ?", whereArgs: ["%$query%"]);
    return results.map(AlbumDatabaseItem.fromMap).toList();
  }

  static Future<List<ArtistDatabaseItem>> searchArtists(String query) async {
    final results = await db.query("artist_items", where: "name LIKE ?", whereArgs: ["%$query%"]);
    return results.map(ArtistDatabaseItem.fromMap).toList();
  }

  // PROVIDER-SPECIFIC CACHE MANAGEMENT
  static Future<void> clearProviderCache(String providerId) async {
    // Get all artwork items for this provider before deleting
    final providerArtwork = await db.query(
      'artwork_items',
      where: 'provider_id = ?',
      whereArgs: [providerId],
    );

    // Delete cached artwork files (all size variants)
    for (final artwork in providerArtwork) {
      final id = artwork['id'] as String;
      final mimeType = artwork['mime_type'] as String;
      await CacheHelper.deleteAllArtworkSizes(id, mimeType);
    }

    // Clear all provider-specific data from database
    await db.transaction((txn) async {
      // Delete song-artist relationships for this provider's songs
      await txn.rawDelete(
        """
        DELETE FROM song_artists
        WHERE song_id IN (SELECT id FROM song_items WHERE provider_id = ?)
        """,
        [providerId],
      );

      // Delete album-artist relationships for this provider's albums
      await txn.rawDelete(
        """
        DELETE FROM album_artists
        WHERE album_id IN (SELECT id FROM album_items WHERE provider_id = ?)
        """,
        [providerId],
      );

      // Delete album-song relationships for this provider's albums
      await txn.rawDelete(
        """
        DELETE FROM album_songs
        WHERE album_id IN (SELECT id FROM album_items WHERE provider_id = ?)
        """,
        [providerId],
      );

      // Delete song-album relationships for this provider's songs
      await txn.rawDelete(
        """
        DELETE FROM album_songs
        WHERE song_id IN (SELECT id FROM song_items WHERE provider_id = ?)
        """,
        [providerId],
      );

      await txn.delete('song_items', where: 'provider_id = ?', whereArgs: [providerId]);
      await txn.delete('album_items', where: 'provider_id = ?', whereArgs: [providerId]);
      await txn.delete('artist_items', where: 'provider_id = ?', whereArgs: [providerId]);
      await txn.delete('artwork_items', where: 'provider_id = ?', whereArgs: [providerId]);
    });

    debugPrint("Cleared cache for provider: $providerId");
  }

  static Future<ProviderStatsDatabaseItem> getProviderStats(String providerId) async {
    final artworkCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM artwork_items WHERE provider_id = ?",
      [providerId],
    );
    final artistCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM artist_items WHERE provider_id = ?",
      [providerId],
    );
    final albumCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM album_items WHERE provider_id = ?",
      [providerId],
    );
    final songCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM song_items WHERE provider_id = ?",
      [providerId],
    );

    return ProviderStatsDatabaseItem(
      artwork: artworkCount.first['count'] as int,
      artists: artistCount.first['count'] as int,
      albums: albumCount.first['count'] as int,
      songs: songCount.first['count'] as int,
    );
  }
}
