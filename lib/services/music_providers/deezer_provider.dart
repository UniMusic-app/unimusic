import 'package:unimusic/services/api/deezer/api.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

class DeezerMusicProvider extends MusicProvider {
  final DeezerApi api;
  const DeezerMusicProvider({required this.api}) : super("Deezer");

  @override
  Stream<Album> getLibraryAlbums() async* {
    yield* api.getFavoriteAlbums();
  }

  @override
  Stream<Artist> getLibraryArtists() async* {
    yield* api.getFavoriteArtists();
  }

  @override
  Stream<Song> getLibrarySongs() async* {
    yield* api.getFavoriteSongs();
  }

  @override
  Stream<SearchHint> getSearchHints({required String query, LibraryItemType? itemType}) async* {
    yield* api.getSearchHints(query: query, itemType: itemType);
  }

  @override
  Stream<MusicItem> getSearchResults({required String query, LibraryItemType? itemType}) async* {
    yield* api.getSearchResults(query: query, itemType: itemType);
  }
}
