import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart";
import "package:unimusic/services/database/cache.dart";
import "package:unimusic/services/database/dao/album_dao.dart";
import "package:unimusic/services/database/dao/artist_dao.dart";
import "package:unimusic/services/database/dao/artwork_dao.dart";
import "package:unimusic/services/database/dao/favourite_dao.dart";
import "package:unimusic/services/database/dao/recent_search_dao.dart";
import "package:unimusic/services/database/dao/song_dao.dart";
import "package:unimusic/services/database/objects.dart";
import "package:unimusic/services/database/tables.dart";
import "package:path/path.dart" as path;
import "package:sqflite/sqflite.dart";

export "package:unimusic/services/database/dao/album_dao.dart";
export "package:unimusic/services/database/dao/artist_dao.dart";
export "package:unimusic/services/database/dao/artwork_dao.dart";
export "package:unimusic/services/database/dao/favourite_dao.dart";
export "package:unimusic/services/database/dao/recent_search_dao.dart";
export "package:unimusic/services/database/dao/song_dao.dart";
export "package:unimusic/services/database/tables.dart";

class DatabaseHelper {
  static late final Database db;

  static SongDao? _songs;
  static AlbumDao? _albums;
  static ArtistDao? _artists;
  static ArtworkDao? _artworks;
  static FavouriteDao? _favourites;
  static RecentSearchDao? _recentSearches;

  static SongDao get songs => _songs ??= SongDao(db);
  static AlbumDao get albums => _albums ??= AlbumDao(db);
  static ArtistDao get artists => _artists ??= ArtistDao(db);
  static ArtworkDao get artworks => _artworks ??= ArtworkDao(db);
  static FavouriteDao get favourites => _favourites ??= FavouriteDao(db);
  static RecentSearchDao get recentSearches =>
      _recentSearches ??= RecentSearchDao(db);

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
      version: 2,
      onCreate: (Database db, int version) async {
        await db.execute("""
          CREATE TABLE ${Tables.recentSearches} (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL
          )
        """);

        await db.execute("""
          CREATE TABLE ${Tables.artworks} (
            id TEXT NOT NULL,
            provider_id TEXT NOT NULL,
            mime_type TEXT NOT NULL,
            size TEXT NOT NULL,
            file_path TEXT,
            PRIMARY KEY(id, size)
          )
        """);

        await db.execute("""
          CREATE TABLE ${Tables.artists} (
            id TEXT PRIMARY KEY,
            provider_id TEXT NOT NULL,
            name TEXT NOT NULL,
            artwork_id TEXT,
            favourite INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(artwork_id) REFERENCES ${Tables.artworks}(id) ON DELETE SET NULL
          )
        """);

        await db.execute("""
          CREATE TABLE ${Tables.albums} (
            id TEXT PRIMARY KEY,
            provider_id TEXT NOT NULL,
            name TEXT NOT NULL,
            artwork_id TEXT,
            favourite INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(artwork_id) REFERENCES ${Tables.artworks}(id) ON DELETE SET NULL
          )
        """);

        await db.execute("""
          CREATE TABLE ${Tables.songs} (
            id TEXT PRIMARY KEY,
            provider_id TEXT NOT NULL,
            name TEXT NOT NULL,
            duration INTEGER NOT NULL,
            album TEXT,
            artwork_id TEXT,
            file_path TEXT,
            disc_number INTEGER,
            track_number INTEGER,
            favourite INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(artwork_id) REFERENCES ${Tables.artworks}(id) ON DELETE SET NULL
          )
        """);

        await db.execute("""
          CREATE TABLE ${Tables.albumArtists} (
            album_id TEXT NOT NULL,
            artist_id TEXT NOT NULL,
            PRIMARY KEY(album_id, artist_id),
            FOREIGN KEY(album_id) REFERENCES ${Tables.albums}(id) ON DELETE CASCADE,
            FOREIGN KEY(artist_id) REFERENCES ${Tables.artists}(id) ON DELETE CASCADE
          )
        """);

        await db.execute("""
          CREATE TABLE ${Tables.songArtists} (
            song_id TEXT NOT NULL,
            artist_id TEXT NOT NULL,
            PRIMARY KEY(song_id, artist_id),
            FOREIGN KEY(song_id) REFERENCES ${Tables.songs}(id) ON DELETE CASCADE,
            FOREIGN KEY(artist_id) REFERENCES ${Tables.artists}(id) ON DELETE CASCADE
          )
        """);

        await db.execute("""
          CREATE TABLE ${Tables.albumSongs} (
            album_id TEXT NOT NULL,
            song_id TEXT NOT NULL,
            PRIMARY KEY(album_id, song_id),
            FOREIGN KEY(album_id) REFERENCES ${Tables.albums}(id) ON DELETE CASCADE,
            FOREIGN KEY(song_id) REFERENCES ${Tables.songs}(id) ON DELETE CASCADE
          )
        """);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE ${Tables.songs} ADD COLUMN disc_number INTEGER",
          );
          await db.execute(
            "ALTER TABLE ${Tables.songs} ADD COLUMN track_number INTEGER",
          );
        }
      },
    );
  }

  static Future<void> cleanupOrphanedArtworks() async {
    final allArtworkItems = await artworks.getAll();
    if (allArtworkItems.isEmpty) return;

    final referencedArtworkIds = <String>{};

    for (final song in await songs.getAll()) {
      if (song.artworkId != null) referencedArtworkIds.add(song.artworkId!);
    }
    for (final album in await albums.getAll()) {
      if (album.artworkId != null) referencedArtworkIds.add(album.artworkId!);
    }
    for (final artist in await artists.getAll()) {
      if (artist.artworkId != null) referencedArtworkIds.add(artist.artworkId!);
    }

    for (final artwork in allArtworkItems) {
      if (!referencedArtworkIds.contains(artwork.id)) {
        await artworks.delete(artwork.id);
      }
    }
  }

  static Future<void> clearAllData() async {
    await CacheHelper.clearArtworkCache();

    await db.transaction((txn) async {
      await txn.delete(Tables.songArtists);
      await txn.delete(Tables.albumArtists);
      await txn.delete(Tables.albumSongs);
      await txn.delete(Tables.songs);
      await txn.delete(Tables.albums);
      await txn.delete(Tables.artists);
      await txn.delete(Tables.artworks);
      await txn.delete(Tables.recentSearches);
    });
  }

  static Future<DatabaseStatsDatabaseItem> getDatabaseStats() async {
    final artworkCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tables.artworks}",
    );
    final artistCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tables.artists}",
    );
    final albumCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tables.albums}",
    );
    final songCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tables.songs}",
    );
    final searchCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tables.recentSearches}",
    );

    return DatabaseStatsDatabaseItem(
      artwork: artworkCount.first["count"] as int,
      artists: artistCount.first["count"] as int,
      albums: albumCount.first["count"] as int,
      songs: songCount.first["count"] as int,
      recentSearches: searchCount.first["count"] as int,
    );
  }

  static Future<CacheStatsDatabaseItem> getCacheStats() async {
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

  static Future<void> clearProviderCache(String providerId) async {
    final providerArtwork = await db.query(
      Tables.artworks,
      where: "provider_id = ?",
      whereArgs: [providerId],
    );

    for (final artwork in providerArtwork) {
      final id = artwork["id"] as String;
      final mimeType = artwork["mime_type"] as String;
      await CacheHelper.deleteAllArtworkSizes(id, mimeType);
    }

    await db.transaction((txn) async {
      await txn.rawDelete(
        """
        DELETE FROM ${Tables.songArtists}
        WHERE song_id IN (SELECT id FROM ${Tables.songs} WHERE provider_id = ?)
        """,
        [providerId],
      );

      await txn.rawDelete(
        """
        DELETE FROM ${Tables.albumArtists}
        WHERE album_id IN (SELECT id FROM ${Tables.albums} WHERE provider_id = ?)
        """,
        [providerId],
      );

      await txn.rawDelete(
        """
        DELETE FROM ${Tables.albumSongs}
        WHERE album_id IN (SELECT id FROM ${Tables.albums} WHERE provider_id = ?)
        """,
        [providerId],
      );

      await txn.rawDelete(
        """
        DELETE FROM ${Tables.albumSongs}
        WHERE song_id IN (SELECT id FROM ${Tables.songs} WHERE provider_id = ?)
        """,
        [providerId],
      );

      await txn.delete(
        Tables.songs,
        where: "provider_id = ?",
        whereArgs: [providerId],
      );
      await txn.delete(
        Tables.albums,
        where: "provider_id = ?",
        whereArgs: [providerId],
      );
      await txn.delete(
        Tables.artists,
        where: "provider_id = ?",
        whereArgs: [providerId],
      );
      await txn.delete(
        Tables.artworks,
        where: "provider_id = ?",
        whereArgs: [providerId],
      );
    });

    debugPrint("Cleared cache for provider: $providerId");
  }

  static Future<ProviderStatsDatabaseItem> getProviderStats(
    String providerId,
  ) async {
    final artworkCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tables.artworks} WHERE provider_id = ?",
      [providerId],
    );
    final artistCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tables.artists} WHERE provider_id = ?",
      [providerId],
    );
    final albumCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tables.albums} WHERE provider_id = ?",
      [providerId],
    );
    final songCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${Tables.songs} WHERE provider_id = ?",
      [providerId],
    );

    return ProviderStatsDatabaseItem(
      artwork: artworkCount.first["count"] as int,
      artists: artistCount.first["count"] as int,
      albums: albumCount.first["count"] as int,
      songs: songCount.first["count"] as int,
    );
  }
}
