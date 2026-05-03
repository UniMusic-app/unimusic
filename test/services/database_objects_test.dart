import "package:flutter_test/flutter_test.dart";
import "package:unimusic/services/database/objects.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

void main() {
  group("SongDatabaseItem.fromMap", () {
    test("parses all fields", () {
      final item = SongDatabaseItem.fromMap({
        "id": "song-1",
        "provider_id": "local",
        "name": "Test Song",
        "duration": 240,
        "album": "Test Album",
        "artwork_id": "art-1",
        "file_path": "/music/test.mp3",
        "favourite": 1,
        "disc_number": 1,
        "track_number": 5,
      });
      expect(item.id, "song-1");
      expect(item.providerId, "local");
      expect(item.name, "Test Song");
      expect(item.duration, 240);
      expect(item.album, "Test Album");
      expect(item.artworkId, "art-1");
      expect(item.filePath, "/music/test.mp3");
      expect(item.favourite, true);
      expect(item.discNumber, 1);
      expect(item.trackNumber, 5);
    });

    test("handles nullable fields as null", () {
      final item = SongDatabaseItem.fromMap({
        "id": "song-2",
        "provider_id": "deezer",
        "name": "Minimal Song",
        "duration": 180,
        "album": null,
        "artwork_id": null,
        "file_path": null,
        "favourite": 0,
        "disc_number": null,
        "track_number": null,
      });
      expect(item.album, isNull);
      expect(item.artworkId, isNull);
      expect(item.filePath, isNull);
      expect(item.favourite, false);
      expect(item.discNumber, isNull);
      expect(item.trackNumber, isNull);
    });
  });

  group("ArtworkDatabaseItem.fromMap", () {
    test("parses all fields", () {
      final item = ArtworkDatabaseItem.fromMap({
        "id": "art-1",
        "provider_id": "local",
        "mime_type": "image/jpeg",
        "size": "large",
        "file_path": "/cache/art.jpg",
      });
      expect(item.id, "art-1");
      expect(item.providerId, "local");
      expect(item.mimeType, "image/jpeg");
      expect(item.size, ArtworkSize.large);
      expect(item.filePath, "/cache/art.jpg");
    });

    test("handles null file_path", () {
      final item = ArtworkDatabaseItem.fromMap({
        "id": "art-2",
        "provider_id": "deezer",
        "mime_type": "image/png",
        "size": "small",
        "file_path": null,
      });
      expect(item.filePath, isNull);
      expect(item.size, ArtworkSize.small);
    });
  });

  group("ArtistDatabaseItem.fromMap", () {
    test("parses all fields", () {
      final item = ArtistDatabaseItem.fromMap({
        "id": "artist-1",
        "provider_id": "jellyfin",
        "name": "Test Artist",
        "artwork_id": "art-3",
        "favourite": 1,
      });
      expect(item.id, "artist-1");
      expect(item.providerId, "jellyfin");
      expect(item.name, "Test Artist");
      expect(item.artworkId, "art-3");
      expect(item.favourite, true);
    });

    test("favourite 0 maps to false", () {
      final item = ArtistDatabaseItem.fromMap({
        "id": "artist-2",
        "provider_id": "local",
        "name": "Another Artist",
        "artwork_id": null,
        "favourite": 0,
      });
      expect(item.favourite, false);
      expect(item.artworkId, isNull);
    });
  });

  group("AlbumDatabaseItem.fromMap", () {
    test("parses all fields", () {
      final item = AlbumDatabaseItem.fromMap({
        "id": "album-1",
        "provider_id": "deezer",
        "name": "Test Album",
        "artwork_id": "art-4",
        "favourite": 1,
      });
      expect(item.id, "album-1");
      expect(item.providerId, "deezer");
      expect(item.name, "Test Album");
      expect(item.artworkId, "art-4");
      expect(item.favourite, true);
    });
  });

  group("RecentSearchDatabaseItem.fromMap", () {
    test("parses all fields", () {
      final item = RecentSearchDatabaseItem.fromMap({
        "id": "search-1",
        "type": "song",
      });
      expect(item.id, "search-1");
      expect(item.type, "song");
    });
  });

  group("DatabaseStatsDatabaseItem.fromMap", () {
    test("parses all fields", () {
      final item = DatabaseStatsDatabaseItem.fromMap({
        "artwork": 100,
        "artists": 50,
        "albums": 30,
        "songs": 500,
        "recent_searches": 10,
      });
      expect(item.artwork, 100);
      expect(item.artists, 50);
      expect(item.albums, 30);
      expect(item.songs, 500);
      expect(item.recentSearches, 10);
    });
  });

  group("CacheStatsDatabaseItem.fromMap", () {
    test("parses all fields", () {
      final item = CacheStatsDatabaseItem.fromMap({
        "artwork_cache_size_bytes": 1048576,
        "artwork_cache_files": 42,
        "artwork_cache_size_mb": "1.00",
        "cache_directory": "/tmp/cache",
      });
      expect(item.artworkCacheSizeBytes, 1048576);
      expect(item.artworkCacheFiles, 42);
      expect(item.artworkCacheSizeMb, "1.00");
      expect(item.cacheDirectory, "/tmp/cache");
    });
  });

  group("ProviderStatsDatabaseItem.fromMap", () {
    test("parses all fields", () {
      final item = ProviderStatsDatabaseItem.fromMap({
        "artwork": 10,
        "artists": 5,
        "albums": 3,
        "songs": 50,
      });
      expect(item.artwork, 10);
      expect(item.artists, 5);
      expect(item.albums, 3);
      expect(item.songs, 50);
    });
  });

  group("ArtworkSize", () {
    test("fromString parses valid sizes", () {
      expect(ArtworkSize.fromString("small"), ArtworkSize.small);
      expect(ArtworkSize.fromString("medium"), ArtworkSize.medium);
      expect(ArtworkSize.fromString("large"), ArtworkSize.large);
    });

    test("fromString throws on unknown size", () {
      expect(() => ArtworkSize.fromString("huge"), throwsException);
    });

    test("toString returns correct string", () {
      expect(ArtworkSize.small.toString(), "small");
      expect(ArtworkSize.medium.toString(), "medium");
      expect(ArtworkSize.large.toString(), "large");
    });

    test("width values are correct", () {
      expect(ArtworkSize.small.width, 96);
      expect(ArtworkSize.medium.width, 256);
      expect(ArtworkSize.large.width, 1024);
    });
  });
}
