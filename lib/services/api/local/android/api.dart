import "package:unimusic/plugins/media_store.dart";
import "package:unimusic/services/api/local/android/items.dart";
import "package:unimusic/services/api/local/api.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class LocalAndroidApi extends LocalApi {
  Stream<LocalAndroidSong> getAllSongs() async* {
    await MediaStorePlugin.requestPermission();

    yield* MediaStorePlugin.getSongs().map(LocalAndroidSong.fromMediaStore);
  }

  Stream<LocalAndroidAlbum> getAllAlbums() async* {
    await MediaStorePlugin.requestPermission();
    yield* MediaStorePlugin.getAlbums().map(LocalAndroidAlbum.fromMediaStore);
  }

  Stream<LocalAndroidArtist> getAllArtists() async* {
    await MediaStorePlugin.requestPermission();
    yield* MediaStorePlugin.getArtists().map(LocalAndroidArtist.fromMediaStore);
  }

  @override
  Stream<SearchHint> getSearchHints({
    required String query,
    required Set<LibraryItemType> itemTypes,
  }) async* {}

  @override
  Stream<MusicItem> search({
    required String query,
    required Set<LibraryItemType> itemTypes,
  }) async* {}
}
