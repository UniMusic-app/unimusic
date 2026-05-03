import "dart:async" show unawaited;

import "package:flutter/foundation.dart";
import "package:audio_session/audio_session.dart";
import "package:flutter/services.dart";
import "package:unimusic/services/audio_routing_service.dart";
import "package:unimusic/services/music_providers/music_provider.dart";
import "package:just_audio/just_audio.dart";

class MusicManager extends ChangeNotifier {
  final player = AudioPlayer(
    useLazyPreparation: true,
    useProxyForRequestHeaders: false,
  );

  final AudioRoutingService _audioRouting = AudioRoutingService();
  AudioRoutingCapabilities audioRoutingCapabilities =
      AudioRoutingCapabilities.unsupported;
  AudioRouteKind currentRouteKind = AudioRouteKind.unknown;

  double volume = 1.0;
  bool isShuffleEnabled = false;
  LoopMode loopMode = LoopMode.off;

  int queuePosition = 0;
  List<Song> queue = [];
  Duration duration = Duration.zero;
  Duration bufferedPosition = Duration.zero;
  Duration position = Duration.zero;

  MusicManager() {
    _init();
  }

  Future<void> _init() async {
    // Configure an audio session suitable for music playback.
    // Using audio_session keeps this maintainable and compatible across iOS/Android.
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Best-effort route refresh when devices change (e.g. headphones unplugged).
      session.devicesChangedEventStream.listen((_) async {
        currentRouteKind = await _audioRouting.getCurrentRouteKind();
        notifyListeners();
      });
    } on MissingPluginException {
      // audio_session may not be available on some desktop targets.
    } catch (e) {
      debugPrint("Audio session init failed: $e");
    }

    audioRoutingCapabilities = await _audioRouting.getCapabilities(
      forceRefresh: true,
    );
    currentRouteKind = await _audioRouting.getCurrentRouteKind();

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

    player.bufferedPositionStream.listen((position) {
      bufferedPosition = position;
      notifyListeners();
    });

    player.playingStream.listen((playing) {
      notifyListeners();
    });

    player.shuffleModeEnabledStream.listen((enabled) {
      isShuffleEnabled = enabled;
      notifyListeners();
    });

    player.loopModeStream.listen((mode) {
      loopMode = mode;
      notifyListeners();
    });

    volume = player.volume;
    player.volumeStream.listen((volume) {
      this.volume = volume;
      notifyListeners();
    });

    notifyListeners();
  }

  Future<void> refreshAudioRoute() async {
    currentRouteKind = await _audioRouting.getCurrentRouteKind();
    notifyListeners();
  }

  Future<void> refreshAudioRoutingCapabilities() async {
    audioRoutingCapabilities = await _audioRouting.getCapabilities(
      forceRefresh: true,
    );
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    this.volume = volume.clamp(0.0, 1.0);
    await player.setVolume(this.volume);
    notifyListeners();
  }

  Future<void> setShuffleModeEnabled(
    bool enabled, {
    bool reshuffle = true,
  }) async {
    await player.setShuffleModeEnabled(enabled);
    if (enabled && reshuffle && player.sequence.isNotEmpty) {
      await player.shuffle();
    }
  }

  Future<void> toggleShuffle() async {
    if (isShuffleEnabled) {
      await setShuffleModeEnabled(false);
      return;
    }

    await setShuffleModeEnabled(true);
  }

  Future<void> cycleLoopMode() async {
    final nextMode = switch (loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };

    await player.setLoopMode(nextMode);
  }

  Future<void> openSystemOutputChooser() async {
    if (!audioRoutingCapabilities.canOpenSystemChooser) return;
    await refreshAudioRoutingCapabilities();
    await refreshAudioRoute();
    final _ = await _audioRouting.openSystemOutputChooser();
    await refreshAudioRoute();
  }

  Future<void> _reshuffleIfEnabled({bool force = false}) async {
    if (!force && !isShuffleEnabled) return;
    if (player.sequence.isEmpty) return;
    await player.shuffle();
  }

  Future<void> clearQueue() async {
    await player.clearAudioSources();
    queue.clear();
    queuePosition = 0;
    notifyListeners();
  }

  Future<void> removeFromQueue(int position) async {
    await player.removeAudioSourceAt(position);
    queue.removeAt(position);
    notifyListeners();
  }

  Future<List<AudioSource>> _resolveAudioSources(Iterable<Song> songs) {
    return Future.wait(songs.map((song) => song.getAudioSource()));
  }

  Future<void> queueSongStream(Stream<Song> songs, {int? position}) async {
    var didAdd = false;
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

      didAdd = true;

      notifyListeners();
    }

    if (didAdd) {
      await _reshuffleIfEnabled();
    }
  }

  Future<void> queueSongs(List<Song> songs, {int? position}) async {
    if (songs.isEmpty) return;

    final audioSources = await _resolveAudioSources(songs);

    if (position != null) {
      queue.insertAll(position, songs);
      await player.insertAudioSources(position, audioSources);
    } else {
      queue.addAll(songs);
      await player.addAudioSources(audioSources);
    }

    notifyListeners();

    await _reshuffleIfEnabled();
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
      case Artist artist:
        await queueSongStream(artist.getFeaturedSongs(), position: position);
    }
  }

  Song? get currentItem => queue.isEmpty ? null : queue[queuePosition];
  bool get isPlaying => player.playing;
  bool get canPlay => currentItem != null;
  Future<void> play() async {
    if (player.currentIndex == queuePosition) {
      unawaited(player.play());
      return;
    }

    await player.seek(Duration.zero, index: queuePosition);
    unawaited(player.play());
  }

  Future<void> playNow(MusicItem item) async {
    if (queue.isNotEmpty) {
      final targetPosition = queuePosition + 1;
      await queueItem(item, position: targetPosition);
      await jumpToQueueItem(targetPosition);
    } else {
      await queueItem(item);
      await play();
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

  bool get canSkipPrevious => player.hasPrevious;
  Future<void> skipPrevious() async {
    if (canSkipPrevious) {
      await player.seekToPrevious();
      if (!player.playing) {
        await player.play();
      }
    }
  }

  bool get canSkipNext => player.hasNext;
  Future<void> skipNext() async {
    if (canSkipNext) {
      await player.seekToNext();
      if (!player.playing) {
        await player.play();
      }
    }
  }

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
    unawaited(player.moveAudioSource(oldIndex, newIndex));

    notifyListeners();
  }
}
