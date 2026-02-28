import 'package:unimusic/services/music_providers/music_provider.dart';

abstract class LocalApi {
  Stream<Song> getAllSongs();
  Stream<Album> getAllAlbums();
  Stream<Artist> getAllArtists();

  Stream<SearchHint> getSearchHints({
    required String query,
    LibraryItemType? itemType,
  });
  Stream<MusicItem> getSearchResults({
    required String query,
    LibraryItemType? itemType,
  });

  Future<void> cleanupGarbage();
}
