import 'package:unimusic/services/api/local/api.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

class LocalMusicProvider extends MusicProvider {
  final LocalApi api;

  LocalMusicProvider({required this.api}) : super("Local Test");

  @override
  Stream<Song> getLibrarySongs() async* {
    final list = await api.getAllSongs().toList();
    for (final item in list) {
      yield item;
    }
  }

  @override
  Stream<Album> getLibraryAlbums() async* {
    yield* api.getAllAlbums();
  }

  @override
  Stream<Artist> getLibraryArtists() async* {
    yield* api.getAllArtists();
  }

  @override
  Stream<SearchHint> getSearchHints({
    required String query,
    required Set<LibraryItemType> itemTypes,
  }) async* {
    yield* api.getSearchHints(query: query, itemTypes: itemTypes);
  }

  @override
  Stream<MusicItem> getSearchResults({
    required String query,
    required Set<LibraryItemType> itemTypes,
  }) async* {
    yield* api.search(query: query, itemTypes: itemTypes);
  }
}
