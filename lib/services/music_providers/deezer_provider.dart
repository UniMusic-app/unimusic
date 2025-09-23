import 'package:unimusic/services/api/deezer/api.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

class DeezerMusicProvider extends MusicProvider {
  final DeezerApi deezer;
  const DeezerMusicProvider({required this.deezer}) : super("Deezer");

  @override
  Stream<Album> getLibraryAlbums() async* {
    yield* deezer.getFavoriteAlbums();
  }

  @override
  Stream<Artist> getLibraryArtists() async* {
    yield* deezer.getFavoriteArtists();
  }

  @override
  Stream<Song> getLibrarySongs() async* {
    yield* deezer.getFavoriteSongs();
  }

  @override
  Stream<SearchHint> getSearchHints({
    required String query,
    required Set<LibraryItemType> itemTypes,
  }) async* {
    yield* deezer.getSearchHints(query: query, itemTypes: itemTypes);
  }

  @override
  Stream<MusicItem> getSearchResults({
    required String query,
    required Set<LibraryItemType> itemTypes,
  }) async* {
    yield* deezer.getSearchResults(query: query, itemTypes: itemTypes);
  }
}
