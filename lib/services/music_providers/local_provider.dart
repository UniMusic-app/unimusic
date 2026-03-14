import 'package:unimusic/services/api/local/api.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

class LocalMusicProvider extends MusicProvider {
  final LocalApi api;

  LocalMusicProvider({required this.api}) : super(id: 'local', name: 'Local');

  @override
  Stream<Song> getLibrarySongs() async* {
    yield* api.getAllSongs();
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
    LibraryItemType? itemType,
  }) async* {
    yield* api.getSearchHints(query: query, itemType: itemType);
  }

  @override
  Stream<MusicItem> getSearchResults({
    required String query,
    LibraryItemType? itemType,
  }) async* {
    yield* api.getSearchResults(query: query, itemType: itemType);
  }

  @override
  Future<void> cleanupGarbage() async {
    await api.cleanupGarbage();
  }
}
