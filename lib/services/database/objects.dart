import 'package:unimusic/services/database/database.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

abstract class DatabaseItem {
  final String id;
  final String providerId;

  const DatabaseItem({required this.id, required this.providerId});
}

abstract class DatabaseArtworkItem extends DatabaseItem {
  final String? artworkId;

  const DatabaseArtworkItem({
    required super.id,
    required super.providerId,
    required this.artworkId,
  });

  Future<ArtworkDatabaseItem?> getArtwork(ArtworkSize size) async {
    if (artworkId == null) {
      return null;
    }
    return DatabaseHelper.getArtwork(artworkId!, size: size);
  }
}

class SongDatabaseItem extends DatabaseArtworkItem {
  final String name;
  final int duration;
  final String? album;
  final bool favourite;
  final String? filePath;

  const SongDatabaseItem({
    required super.id,
    required super.providerId,
    required super.artworkId,
    required this.name,
    required this.duration,
    required this.album,
    required this.filePath,
    required this.favourite,
  });

  factory SongDatabaseItem.fromMap(Map<String, dynamic> map) => SongDatabaseItem(
    id: map["id"],
    providerId: map["provider_id"],
    name: map["name"],
    duration: map["duration"],
    album: map["album"],
    artworkId: map["artwork_id"],
    filePath: map["file_path"],
    favourite: map["favourite"] == 1,
  );

  Future<List<ArtistDatabaseItem>> getSongArtists() async {
    return await DatabaseHelper.getSongArtists(id);
  }
}

class ArtworkDatabaseItem extends DatabaseItem {
  final String mimeType;
  final ArtworkSize size;
  final String? filePath;

  const ArtworkDatabaseItem({
    required super.id,
    required super.providerId,
    required this.mimeType,
    required this.size,
    required this.filePath,
  });

  factory ArtworkDatabaseItem.fromMap(Map<String, dynamic> map) => ArtworkDatabaseItem(
    id: map["id"],
    providerId: map["provider_id"],
    mimeType: map["mime_type"],
    size: ArtworkSize.fromString(map["size"]),
    filePath: map["file_path"],
  );
}

class ArtistDatabaseItem extends DatabaseArtworkItem {
  final String name;
  final bool favourite;

  const ArtistDatabaseItem({
    required super.id,
    required super.providerId,
    required super.artworkId,
    required this.name,
    required this.favourite,
  });

  factory ArtistDatabaseItem.fromMap(Map<String, dynamic> map) => ArtistDatabaseItem(
    id: map["id"],
    providerId: map["provider_id"],
    name: map["name"],
    artworkId: map["artwork_id"],
    favourite: map["favourite"] == 1,
  );
}

class AlbumDatabaseItem extends DatabaseArtworkItem {
  final String name;
  final bool favourite;

  const AlbumDatabaseItem({
    required super.id,
    required super.providerId,
    required super.artworkId,
    required this.name,
    required this.favourite,
  });

  factory AlbumDatabaseItem.fromMap(Map<String, dynamic> map) => AlbumDatabaseItem(
    id: map["id"],
    providerId: map["provider_id"],
    name: map["name"],
    artworkId: map["artwork_id"],
    favourite: map["favourite"] == 1,
  );
}

class RecentSearchDatabaseItem {
  final String id;
  final String type;

  const RecentSearchDatabaseItem({required this.id, required this.type});

  factory RecentSearchDatabaseItem.fromMap(Map<String, dynamic> map) =>
      RecentSearchDatabaseItem(id: map["id"], type: map["type"]);
}

class DatabaseStatsDatabaseItem {
  final int artwork;
  final int artists;
  final int albums;
  final int songs;
  final int recentSearches;

  const DatabaseStatsDatabaseItem({
    required this.artwork,
    required this.artists,
    required this.albums,
    required this.songs,
    required this.recentSearches,
  });

  factory DatabaseStatsDatabaseItem.fromMap(Map<String, int> map) => DatabaseStatsDatabaseItem(
    artwork: map["artwork"]!,
    artists: map["artists"]!,
    albums: map["albums"]!,
    songs: map["songs"]!,
    recentSearches: map["recent_searches"]!,
  );
}

class CacheStatsDatabaseItem {
  final int artworkCacheSizeBytes;
  final int artworkCacheFiles;
  final String artworkCacheSizeMb;
  final String cacheDirectory;

  const CacheStatsDatabaseItem({
    required this.artworkCacheSizeBytes,
    required this.artworkCacheFiles,
    required this.artworkCacheSizeMb,
    required this.cacheDirectory,
  });

  factory CacheStatsDatabaseItem.fromMap(Map<String, dynamic> map) => CacheStatsDatabaseItem(
    artworkCacheSizeBytes: map["artwork_cache_size_bytes"],
    artworkCacheFiles: map["artwork_cache_files"],
    artworkCacheSizeMb: map["artwork_cache_size_mb"],
    cacheDirectory: map["cache_directory"],
  );
}

class ProviderStatsDatabaseItem {
  final int artwork;
  final int artists;
  final int albums;
  final int songs;

  const ProviderStatsDatabaseItem({
    required this.artwork,
    required this.artists,
    required this.albums,
    required this.songs,
  });

  factory ProviderStatsDatabaseItem.fromMap(Map<String, int> map) => ProviderStatsDatabaseItem(
    artwork: map["artwork"]!,
    artists: map["artists"]!,
    albums: map["albums"]!,
    songs: map["songs"]!,
  );
}
