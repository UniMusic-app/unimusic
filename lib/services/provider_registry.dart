import "package:async/async.dart";
import "package:flutter/foundation.dart";
import "package:unimusic/services/api/deezer/api.dart";
import "package:unimusic/services/api/jellyfin/api.dart";
import "package:unimusic/services/api/local/android/api.dart";
import "package:unimusic/services/api/local/api.dart" show LocalApi;
import "package:unimusic/services/api/local/shared/api.dart";
import "package:unimusic/services/credentials_service.dart";
import "package:unimusic/services/music_providers/deezer_provider.dart";
import "package:unimusic/services/music_providers/jellyfin_provider.dart";
import "package:unimusic/services/music_providers/local_provider.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class ProviderRegistry extends ChangeNotifier {
  final Set<MusicProvider> providers = {};
  final Set<ServiceCredentials> _credentials = {};
  final Map<ServiceCredentials, MusicProvider> _credentialProviders = {};

  ProviderRegistry() {
    _loadServicesFromCredentials();
  }

  /// Loads all services from stored credentials.
  Future<void> _loadServicesFromCredentials() async {
    final credentials = await CredentialsService.instance.getCredentials();
    for (final credential in credentials) {
      try {
        await addServiceFromCredentials(credential);
      } catch (e, st) {
        debugPrint("Failed to load service $credential: $e\n$st");
      }
    }
  }

  Future<void> addServiceFromCredentials(ServiceCredentials credentials) async {
    removeService(credentials);

    final MusicProvider provider;
    switch (credentials) {
      case LocalCredentials credentials:
        final LocalApi api;
        final isAndroid = defaultTargetPlatform == TargetPlatform.android;

        if (isAndroid) {
          api = LocalAndroidApi();
        } else if (credentials.useDefaultDirectories) {
          final musicDirectories =
              await LocalSharedApi.getDefaultMusicDirectories();
          api = LocalSharedApi(musicDirectories: musicDirectories);
        } else if (credentials.customDirectory != null) {
          api = LocalSharedApi(
            musicDirectories: [credentials.customDirectory!],
          );
        } else {
          throw Exception("Invalid local credentials: no directory specified");
        }
        provider = LocalMusicProvider(api: api);
      case JellyfinCredentials credentials:
        final api = await JellyfinApi.authenticateByName(
          serverUri: Uri.parse(credentials.serverUri),
          username: credentials.username,
          password: credentials.password,
        );
        provider = JellyfinMusicProvider(api: api);
      case DeezerCredentials credentials:
        final api = await DeezerApi.create(arl: credentials.arl);
        provider = DeezerMusicProvider(api: api);
    }

    providers.add(provider);
    _credentials.add(credentials);
    _credentialProviders[credentials] = provider;
    notifyListeners();
  }

  /// Removes a service provider by its credentials.
  void removeService(ServiceCredentials credentials) {
    final provider = _credentialProviders.remove(credentials);
    if (provider != null) {
      providers.remove(provider);
      _credentials.remove(credentials);
      notifyListeners();
    }
  }

  Stream<MusicItem> getLibraryItems({LibraryItemType? itemType}) async* {
    final pendingMusicItems = providers.map(
      (provider) => provider.getLibraryItems(itemType: itemType),
    );
    final mergedStream = StreamGroup.merge(pendingMusicItems);
    yield* mergedStream;
  }

  Stream<SearchHint> getSearchHints({
    required String query,
    LibraryItemType? itemType,
  }) async* {
    final pendingSearchHints = providers.map(
      (provider) => provider.getSearchHints(query: query, itemType: itemType),
    );
    final mergedStream = StreamGroup.merge(pendingSearchHints);
    yield* mergedStream;
  }

  Stream<MusicItem> getSearchResults({
    required String query,
    LibraryItemType? itemType,
  }) async* {
    final pendingSearchResults = providers.map(
      (provider) => provider.getSearchResults(query: query, itemType: itemType),
    );
    final mergedStream = StreamGroup.merge(pendingSearchResults);
    yield* mergedStream;
  }
}
