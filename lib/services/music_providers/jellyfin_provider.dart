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
  Stream<MusicItem> getSearchResults({required String query, LibraryItemType? itemType}) async* {
    yield* api.items(
      searchTerm: query,
      recursive: true,
      includeItemTypes: switch (itemType) {
        LibraryItemType itemType => {JellyfinItemType.fromLibraryItemType(itemType)},
        null => null,
      },
    );
  }

  @override
  Stream<SearchHint> getSearchHints({required String query, LibraryItemType? itemType}) async* {
    yield* api.searchHints(
      searchTerm: query,
      includeItemTypes: switch (itemType) {
        LibraryItemType itemType => {JellyfinItemType.fromLibraryItemType(itemType)},
        null => null,
      },
    );
  }
}
