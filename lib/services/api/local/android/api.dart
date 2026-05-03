import "package:unimusic/plugins/media_store.dart";
import "package:unimusic/services/api/local/android/items.dart";
import "package:unimusic/services/api/local/api.dart";
import "package:unimusic/services/database/database.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class LocalAndroidApi extends LocalApi {
  @override
  Stream<LocalAndroidSong> getAllSongs() async* {
    await MediaStorePlugin.requestPermission();
    yield* MediaStorePlugin.getSongs().asyncMap(
      LocalAndroidSong.fromMediaStore,
    );
  }

  @override
  Stream<LocalAndroidAlbum> getAllAlbums() async* {
    await MediaStorePlugin.requestPermission();
    yield* MediaStorePlugin.getAlbums().asyncMap(
      LocalAndroidAlbum.fromMediaStore,
    );
  }

  @override
  Stream<LocalAndroidArtist> getAllArtists() async* {
    await MediaStorePlugin.requestPermission();
    yield* MediaStorePlugin.getArtists().asyncMap(
      LocalAndroidArtist.fromMediaStore,
    );
  }

  @override
  Stream<SearchHint> getSearchHints({
    required String query,
    LibraryItemType? itemType,
  }) async* {}

  @override
  Stream<MusicItem> getSearchResults({
    required String query,
    LibraryItemType? itemType,
  }) async* {}

  @override
  Future<void> cleanupGarbage() async {
    await MediaStorePlugin.requestPermission();

    final mediaStoreSongs = await MediaStorePlugin.getSongs()
        .map((s) => s.id.toString())
        .toSet();
    final dbSongs = await DatabaseHelper.songs.getByProvider(providerId);
    for (final dbSong in dbSongs) {
      if (!mediaStoreSongs.contains(dbSong.id)) {
        await DatabaseHelper.songs.delete(dbSong.id);
      }
    }

    final mediaStoreAlbums = await MediaStorePlugin.getAlbums()
        .map((a) => a.id.toString())
        .toSet();
    final dbAlbums = await DatabaseHelper.albums.getByProvider(providerId);
    for (final dbAlbum in dbAlbums) {
      if (!mediaStoreAlbums.contains(dbAlbum.id)) {
        await DatabaseHelper.albums.delete(dbAlbum.id);
      }
    }

    final mediaStoreArtists = await MediaStorePlugin.getArtists()
        .map((a) => a.id.toString())
        .toSet();
    final dbArtists = await DatabaseHelper.artists.getByProvider(providerId);
    for (final dbArtist in dbArtists) {
      if (!mediaStoreArtists.contains(dbArtist.id)) {
        await DatabaseHelper.artists.delete(dbArtist.id);
      }
    }

    await DatabaseHelper.cleanupOrphanedArtworks();
  }
}
