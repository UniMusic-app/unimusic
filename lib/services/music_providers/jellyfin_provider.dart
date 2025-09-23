import 'package:unimusic/services/api/jellyfin/api.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

class JellyfinMusicProvider extends MusicProvider {
  final JellyfinApi api;
  JellyfinMusicProvider({required this.api}) : super("Jellyfin");

  @override
  Stream<Song> getLibrarySongs() async* {
    yield* api.items(recursive: true, includeItemTypes: {JellyfinItemType.audio}).cast();
  }

  @override
  Stream<Album> getLibraryAlbums() async* {
    yield* api.items(recursive: true, includeItemTypes: {JellyfinItemType.musicAlbum}).cast();
  }

  @override
  Stream<Artist> getLibraryArtists() async* {
    yield* api.artists(recursive: true).cast();
  }

  @override
  Stream<MusicItem> getSearchResults({
    required String query,
    required Set<LibraryItemType> itemTypes,
  }) async* {
    yield* api.items(
      searchTerm: query,
      recursive: true,
      includeItemTypes: itemTypes.map(JellyfinItemType.fromLibraryItemType).toSet(),
    );
  }

  @override
  Stream<SearchHint> getSearchHints({
    required String query,
    required Set<LibraryItemType> itemTypes,
  }) async* {
    yield* api.searchHints(
      searchTerm: query,
      includeItemTypes: itemTypes.map(JellyfinItemType.fromLibraryItemType).toSet(),
    );
  }
}
