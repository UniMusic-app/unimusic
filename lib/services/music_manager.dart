import 'dart:io';

import 'package:async/async.dart';
import 'package:flutter/cupertino.dart';
import 'package:unimusic/services/api/deezer/api.dart';
import 'package:unimusic/services/api/jellyfin/api.dart';
import 'package:unimusic/services/api/local/android/api.dart';
import 'package:unimusic/services/api/local/api.dart' show LocalApi;
import 'package:unimusic/services/api/local/shared/api.dart';
import 'package:unimusic/services/credentials_service.dart';
import 'package:unimusic/services/music_providers/deezer_provider.dart';
import 'package:unimusic/services/music_providers/jellyfin_provider.dart';
import 'package:unimusic/services/music_providers/local_provider.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:just_audio/just_audio.dart';

class MusicManager extends ChangeNotifier {
  final player = AudioPlayer(
    useLazyPreparation: true,
    useProxyForRequestHeaders: false,
  );
  final Set<MusicProvider> providers = {};
  final Set<ServiceCredentials> _credentials = {};
  final Map<ServiceCredentials, MusicProvider> _credentialProviders = {};

  MusicManager() {
    _init();
  }

  _init() async {
    await _loadServicesFromCredentials();

    player.currentIndexStream.listen((currentIndex) {
      queuePosition = currentIndex ?? 0;
      notifyListeners();
    });

    player.positionStream.listen((position) {
      this.position = position;
      notifyListeners();
    });

    player.durationStream.listen((duration) {
      if (duration != null) {
        this.duration = duration;
      }
      notifyListeners();
    });

    player.playingStream.listen((playing) {
      notifyListeners();
    });

    notifyListeners();
  }

  /// Loads all services from stored credentials.
  Future<void> _loadServicesFromCredentials() async {
    final credentials = await CredentialsService.instance.getCredentials();
    for (final credential in credentials) {
      try {
        await addServiceFromCredentials(credential);
      } catch (e) {
        debugPrint('Failed to load service $credential: $e');
      }
    }
  }

  Future<void> addServiceFromCredentials(ServiceCredentials credentials) async {
    removeService(credentials);

    final MusicProvider provider;
    switch (credentials) {
      case LocalCredentials credentials:
        final LocalApi api;
        if (Platform.isAndroid) {
          // Android always uses MediaStore
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
          throw Exception('Invalid local credentials: no directory specified');
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

  int queuePosition = 0;
  List<Song> queue = [];
  Duration duration = Duration.zero;

  Future<void> clearQueue() async {
    await player.clearAudioSources();
    queue.clear();
    notifyListeners();
  }

  Future<void> removeFromQueue(int position) async {
    await player.removeAudioSourceAt(position);
    queue.removeAt(position);
    notifyListeners();
  }

  Future<void> queueSongStream(Stream<Song> songs, {int? position}) async {
    await for (final song in songs) {
      final audioSource = await song.getAudioSource();

      if (position != null) {
        queue.insert(position, song);
        await player.insertAudioSource(position, audioSource);
        position += 1;
      } else {
        queue.add(song);
        await player.addAudioSource(audioSource);
      }

      notifyListeners();
    }
  }

  Future<void> queueSongs(List<Song> songs, {int? position}) async {
    for (final song in songs) {
      final audioSource = await song.getAudioSource();

      if (position != null) {
        queue.insert(position, song);
        await player.insertAudioSource(position, audioSource);
        position += 1;
      } else {
        queue.add(song);
        await player.addAudioSource(audioSource);
      }

      notifyListeners();
    }
  }

  Future<void> queueSong(Song song, {int? position}) async {
    await queueSongs([song], position: position);
  }

  Future<void> queueAlbum(Album album, {int? position}) async {
    final songs = album.getSongs();
    await queueSongStream(songs, position: position);
  }

  Future<void> queueItem(MusicItem item, {int? position}) async {
    switch (item) {
      case Song song:
        await queueSong(song, position: position);
      case Album album:
        await queueAlbum(album, position: position);
      default:
        throw UnimplementedError();
    }
  }

  Song? get currentItem => queue.isEmpty ? null : queue[queuePosition];
  bool get isPlaying => player.playing;
  bool get canPlay => currentItem != null;
  Future<void> play() async {
    if (player.currentIndex == queuePosition) {
      player.play();
      return;
    }

    await player.seek(Duration.zero, index: queuePosition);
    player.play();
  }

  Future<void> playNow(MusicItem item) async {
    if (queue.isNotEmpty) {
      final targetPosition = queuePosition + 1;
      await queueItem(item, position: targetPosition);
      await jumpToQueueItem(targetPosition);
    } else {
      await queueItem(item);
    }
  }

  Future<void> pause() async {
    await player.pause();
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> stop() async {
    await player.stop();
    queuePosition = 0;
  }

  bool get canSkipPrevious => queuePosition > 0;
  Future<void> skipPrevious() async {
    if (canSkipPrevious) {
      queuePosition -= 1;
      await play();
    }
  }

  bool get canSkipNext => queuePosition < queue.length - 1;
  Future<void> skipNext() async {
    if (canSkipNext) {
      queuePosition += 1;
      await play();
    }
  }

  Duration position = Duration.zero;
  Future<void> seek(Duration to) async {
    position = to;
    await player.seek(to);
  }

  Future<void> jumpToQueueItem(int index) async {
    if (index >= 0 && index < queue.length) {
      await player.seek(Duration.zero, index: index);
      if (!player.playing) {
        await player.play();
      }
    }
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    // Adjust needed, removing shifts later indices to the left by one
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final song = queue.removeAt(oldIndex);
    queue.insert(newIndex, song);
    player.moveAudioSource(oldIndex, newIndex);

    notifyListeners();
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
