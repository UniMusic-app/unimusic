import "package:unimusic/plugins/media_store.dart";
import "package:unimusic/services/api/local/android/items.dart";
import "package:unimusic/services/api/local/api.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class LocalAndroidApi extends LocalApi {
  @override
  Stream<LocalAndroidSong> getAllSongs() async* {
    await MediaStorePlugin.requestPermission();
    yield* MediaStorePlugin.getSongs().asyncMap(LocalAndroidSong.fromMediaStore);
  }

  @override
  Stream<LocalAndroidAlbum> getAllAlbums() async* {
    await MediaStorePlugin.requestPermission();
    yield* MediaStorePlugin.getAlbums().asyncMap(LocalAndroidAlbum.fromMediaStore);
  }

  @override
  Stream<LocalAndroidArtist> getAllArtists() async* {
    await MediaStorePlugin.requestPermission();
    yield* MediaStorePlugin.getArtists().asyncMap(LocalAndroidArtist.fromMediaStore);
  }

  @override
  Stream<SearchHint> getSearchHints({required String query, LibraryItemType? itemType}) async* {}

  @override
  Stream<MusicItem> getSearchResults({required String query, LibraryItemType? itemType}) async* {}
}
