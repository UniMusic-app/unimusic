import 'package:unimusic/services/music_providers/music_provider.dart';

abstract class LocalApi {
  Stream<Song> getAllSongs();
  Stream<Album> getAllAlbums();
  Stream<Artist> getAllArtists();

  Stream<SearchHint> getSearchHints({
    required String query,
    required Set<LibraryItemType> itemTypes,
  });
  Stream<MusicItem> search({
    required String query,
    required Set<LibraryItemType> itemTypes,
  });
}
