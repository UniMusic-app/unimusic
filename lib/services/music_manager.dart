import 'package:async/async.dart';
import 'package:flutter/cupertino.dart';

import 'package:unimusic/services/api/jellyfin/api.dart';
import 'package:unimusic/services/api/local/api.dart';

import 'package:unimusic/services/music_providers/jellyfin_provider.dart';
import 'package:unimusic/services/music_providers/local_provider.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:just_audio/just_audio.dart';

class MusicManager extends ChangeNotifier {
  final player = AudioPlayer(useLazyPreparation: true, useProxyForRequestHeaders: false);
  final Set<MusicProvider> providers = {};

  MusicManager() {
    _init();
  }

  _init() async {
    final jellyfinApi = await JellyfinApi.authenticateByName(
      serverUri: Uri.parse("https://demo.jellyfin.org/stable"),
      username: "demo",
    );
    final jellyfinProvider = JellyfinMusicProvider(api: jellyfinApi);
    providers.add(jellyfinProvider);

    final localApi = LocalApi(musicDirectories: LocalApi.getDefaultMusicDirectories());
    final localProvider = LocalMusicProvider(api: localApi);
    providers.add(localProvider);

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

  int queuePosition = 0;
  List<Song> queue = [];
  Duration duration = Duration.zero;

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

  Future<void> queueItem(MusicItem item) async {
    switch (item) {
      case Song song:
        await queueSong(song);
      case Album album:
        await queueAlbum(album);
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

  Stream<MusicItem> getLibraryItems({required Set<LibraryItemType> itemTypes}) async* {
    final pendingMusicItems = providers.map(
      (provider) => provider.getLibraryItems(itemTypes: itemTypes),
    );
    final mergedStream = StreamGroup.merge(pendingMusicItems);
    yield* mergedStream;
  }

  Stream<SearchHint> getSearchHints({
    required String query,
    Set<LibraryItemType> itemTypes = const {
      LibraryItemType.songs,
      LibraryItemType.albums,
      LibraryItemType.artists,
    },
  }) async* {
    final pendingSearchHints = providers.map(
      (provider) => provider.getSearchHints(query: query, itemTypes: itemTypes),
    );
    final mergedStream = StreamGroup.merge(pendingSearchHints);
    yield* mergedStream;
  }

  Stream<MusicItem> getSearchResults({
    required String query,
    Set<LibraryItemType> itemTypes = const {
      LibraryItemType.songs,
      LibraryItemType.albums,
      LibraryItemType.artists,
    },
  }) async* {
    final pendingSearchResults = providers.map(
      (provider) => provider.getSearchResults(query: query, itemTypes: itemTypes),
    );
    final mergedStream = StreamGroup.merge(pendingSearchResults);
    yield* mergedStream;
  }
}
