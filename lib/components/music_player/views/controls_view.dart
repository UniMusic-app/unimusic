import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:unimusic/components/lazy_image.dart';
import 'package:unimusic/services/api/deezer/api.dart';
import 'package:unimusic/services/api/deezer/items.dart';
import 'package:unimusic/services/api/jellyfin/items.dart';
import 'package:unimusic/services/api/local/android/items.dart';
import 'package:unimusic/services/api/local/shared/items.dart';
import 'package:unimusic/services/music_manager.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/utils/duration.dart';

class MusicControlsView extends StatefulWidget {
  const MusicControlsView({super.key});

  @override
  State<StatefulWidget> createState() => MusicControlsViewState();
}

class MusicControlsViewState extends State<MusicControlsView> {
  @override
  Widget build(BuildContext context) {
    final musicManager = context.watch<MusicManager>();
    final currentItem = musicManager.currentItem;
    final isShuffleEnabled = musicManager.isShuffleEnabled;
    final loopMode = musicManager.loopMode;

    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final double artworkWidth = min(size.width - 48, size.height - 384);

    final view = View.of(context);
    final safeAreaPadding = MediaQueryData.fromView(view).padding;
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24 + safeAreaPadding.horizontal,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              child: LazyImage(
                animationDuration: Duration(milliseconds: 350),
                icon: Icon(Icons.music_note),
                artwork: currentItem?.artwork,
                width: artworkWidth,
                size: ArtworkSize.large,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: MarqueeText(
              text: currentItem?.name ?? "Nothing is playing",
              style: theme.textTheme.headlineSmall,
            ),
          ),
          Text(
            currentItem?.artists.formatted ?? "",
            style: theme.textTheme.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: musicManager.toggleShuffle,
                      icon: const Icon(Icons.shuffle_rounded),
                      color: isShuffleEnabled ? activeColor : inactiveColor,
                      tooltip: isShuffleEnabled ? 'Shuffle on' : 'Shuffle off',
                    ),
                    IconButton(
                      onPressed: musicManager.cycleLoopMode,
                      icon: Icon(
                        loopMode == LoopMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                      ),
                      color: loopMode == LoopMode.off
                          ? inactiveColor
                          : activeColor,
                      tooltip: switch (loopMode) {
                        LoopMode.off => 'Loop off',
                        LoopMode.all => 'Loop all',
                        LoopMode.one => 'Loop one',
                      },
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    // Skip to previous
                    IconButton(
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      iconSize: 48,
                      onPressed: musicManager.canSkipPrevious
                          ? musicManager.skipPrevious
                          : null,
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                    // Play/pause
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      iconSize: 48,
                      onPressed: musicManager.canPlay
                          ? musicManager.togglePlayPause
                          : null,
                      icon: Icon(
                        musicManager.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    // Skip to next
                    IconButton(
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      iconSize: 48,
                      onPressed: musicManager.canSkipNext
                          ? musicManager.skipNext
                          : null,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                  ],
                ),
                FutureBuilder(
                  future: currentItem?.isFavourite(),
                  builder: (context, snapshot) {
                    if (snapshot.data != null) {
                      return IconButton(
                        color: Colors.pinkAccent,
                        icon: AnimatedCrossFade(
                          duration: Duration(milliseconds: 150),
                          crossFadeState: snapshot.data!
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          firstChild: const Icon(Icons.favorite_rounded),
                          secondChild: const Icon(
                            Icons.favorite_outline_rounded,
                          ),
                        ),
                        onPressed: () async {
                          await currentItem?.toggleFavourite(!snapshot.data!);
                          setState(() {});
                        },
                      );
                    }

                    return IconButton(
                      onPressed: null,
                      icon: Icon(Icons.favorite_outline_rounded),
                    );
                  },
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: ExpandedMusicPlayerSeekbar(),
          ),
        ],
      ),
    );
  }
}

class ExpandedMusicPlayerSeekbar extends StatefulWidget {
  const ExpandedMusicPlayerSeekbar({super.key});

  @override
  State<ExpandedMusicPlayerSeekbar> createState() =>
      ExpandedMusicPlayerSeekbarState();
}

class ExpandedMusicPlayerSeekbarState
    extends State<ExpandedMusicPlayerSeekbar> {
  Duration? _seekBarPosition;

  @override
  Widget build(BuildContext context) {
    final musicManager = context.watch<MusicManager>();

    final maxValue = musicManager.duration.inMilliseconds.toDouble();
    final value = min(
      (_seekBarPosition ?? musicManager.position).inMilliseconds.toDouble(),
      maxValue,
    );
    final buffered = musicManager.bufferedPosition.inMilliseconds.toDouble();
    final bufferedValue = maxValue <= 0
        ? 0.0
        : max(min(buffered, maxValue), value);

    final theme = Theme.of(context);
    final textTimeStyle = theme.textTheme.labelSmall?.apply(
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return Column(
      children: [
        Slider(
          min: 0,
          value: value,
          max: maxValue,
          secondaryTrackValue: bufferedValue,
          padding: EdgeInsets.zero,
          onChanged: (value) {
            setState(() {
              _seekBarPosition = Duration(milliseconds: value.toInt());
            });
          },
          onChangeEnd: (value) async {
            await musicManager.seek(Duration(milliseconds: value.toInt()));
            _seekBarPosition = null;
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              (_seekBarPosition ?? musicManager.position).formatted,
              style: textTimeStyle,
            ),
            StreamInfoLabel(
              song: musicManager.currentItem,
              style: textTimeStyle?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              (-(musicManager.duration - musicManager.position)).formatted,
              style: textTimeStyle,
            ),
          ],
        ),
      ],
    );
  }
}

class StreamInfoLabel extends StatefulWidget {
  final Song? song;
  final TextStyle? style;

  const StreamInfoLabel({super.key, required this.song, this.style});

  @override
  State<StreamInfoLabel> createState() => _StreamInfoLabelState();
}

class _StreamInfoLabelState extends State<StreamInfoLabel> {
  Future<String>? _labelFuture;
  String? _songKey;

  @override
  void initState() {
    super.initState();
    _updateFuture();
  }

  @override
  void didUpdateWidget(covariant StreamInfoLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_songKey != _makeSongKey(widget.song)) {
      _updateFuture();
    }
  }

  void _updateFuture() {
    _songKey = _makeSongKey(widget.song);
    _labelFuture = _buildStreamInfoLabel(widget.song);
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _fallbackLabel(widget.song);
    return FutureBuilder<String>(
      future: _labelFuture,
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? fallback,
          style: widget.style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

String? _makeSongKey(Song? song) {
  if (song == null) {
    return null;
  }

  return "${song.providerId}:${song.id}";
}

String _fallbackLabel(Song? song) {
  if (song == null) {
    return "Unknown";
  }

  final provider = _providerLabel(song.providerId);
  final extension = _fileExtensionFromPath(song.filePath);
  return _labelFromFormat(provider, extension, null);
}

Future<String> _buildStreamInfoLabel(Song? song) async {
  if (song == null) {
    return "Unknown";
  }

  final provider = _providerLabel(song.providerId);

  switch (song) {
    case DeezerSong song:
      final info = _deezerFormatInfo(song.soundFormat);
      return _labelFromFormat(provider, info.format, info.bitrateKbps);
    case JellyfinSong song:
      final info = await song.getStreamInfo();
      return _labelFromStreamInfo(provider, info);
    case LocalSong song:
      final extension = _fileExtensionFromPath(song.filePath);
      return _labelFromFormat(provider, extension, song.bitrateKbps);
    case LocalAndroidSong song:
      final format =
          _formatFromMimeType(song.mimeType) ??
          _fileExtensionFromPath(song.filePath);
      return _labelFromFormat(provider, format, song.bitrateKbps);
    default:
      final extension = _fileExtensionFromPath(song.filePath);
      return _labelFromFormat(provider, extension, null);
  }
}

String _labelFromStreamInfo(String provider, JellyfinStreamInfo? info) {
  if (info == null) {
    return provider;
  }

  final format = _formatFromCodecOrContainer(info.codec, info.container);
  final bitrateKbps = info.bitRate != null
      ? (info.bitRate! / 1000).round()
      : null;
  return _labelFromFormat(
    provider,
    format,
    bitrateKbps,
    sampleRateHz: info.sampleRate,
  );
}

String _labelFromFormat(
  String provider,
  String? format,
  int? bitrateKbps, {
  int? sampleRateHz,
}) {
  final parts = <String>[];
  if (format != null && format.isNotEmpty) {
    parts.add(format);
  }
  if (bitrateKbps != null && bitrateKbps > 0) {
    parts.add("${bitrateKbps} kbps");
  }
  if (sampleRateHz != null && sampleRateHz > 0) {
    parts.add(_formatSampleRate(sampleRateHz));
  }

  if (parts.isEmpty) {
    return provider;
  }

  return "$provider - ${parts.join(" ")}";
}

String _formatSampleRate(int sampleRateHz) {
  final khz = sampleRateHz / 1000;
  final rounded = khz.roundToDouble();
  final label = (khz - rounded).abs() < 0.05
      ? rounded.toStringAsFixed(0)
      : khz.toStringAsFixed(1);
  return "$label kHz";
}

String? _formatFromMimeType(String? mimeType) {
  if (mimeType == null || mimeType.isEmpty) {
    return null;
  }

  final normalized = mimeType.toLowerCase();
  if (normalized.contains("flac")) {
    return "FLAC";
  }
  if (normalized.contains("mpeg") || normalized.contains("mp3")) {
    return "MP3";
  }
  if (normalized.contains("aac")) {
    return "AAC";
  }
  if (normalized.contains("mp4") || normalized.contains("m4a")) {
    return "M4A";
  }
  if (normalized.contains("ogg") || normalized.contains("opus")) {
    return "OGG";
  }
  if (normalized.contains("wav")) {
    return "WAV";
  }
  if (normalized.contains("wma")) {
    return "WMA";
  }

  return null;
}

String? _formatFromCodecOrContainer(String? codec, String? container) {
  final raw = (codec?.trim().isNotEmpty ?? false) ? codec : container;
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }

  return raw.toUpperCase();
}

({String? format, int? bitrateKbps}) _deezerFormatInfo(
  DeezerSoundFormat format,
) {
  return switch (format) {
    DeezerSoundFormat.flac => (format: "FLAC", bitrateKbps: null),
    DeezerSoundFormat.mp3_128kb => (format: "MP3", bitrateKbps: 128),
    DeezerSoundFormat.mp3_320kb => (format: "MP3", bitrateKbps: 320),
  };
}

String _providerLabel(String providerId) {
  return switch (providerId) {
    "local" => "Local",
    "deezer" => "Deezer",
    "jellyfin" => "Jellyfin",
    _ =>
      providerId.isEmpty
          ? "Unknown"
          : "${providerId[0].toUpperCase()}${providerId.substring(1)}",
  };
}

String? _fileExtensionFromPath(String? path) {
  if (path == null || path.isEmpty) {
    return null;
  }

  final lastSegment = path.split(RegExp(r'[\\/]')).last;
  final dotIndex = lastSegment.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == lastSegment.length - 1) {
    return null;
  }

  final extension = lastSegment.substring(dotIndex + 1).trim();
  if (extension.isEmpty) {
    return null;
  }

  return extension.toUpperCase();
}

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration pause;
  final double velocity;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.pause = const Duration(milliseconds: 1200),
    this.velocity = 30,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _scrollController = ScrollController();
  int _scrollToken = 0;
  double _lastDistance = 0;
  bool _isScrolling = false;

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _stopScrolling();
    }
  }

  @override
  void dispose() {
    _scrollToken += 1;
    _scrollController.dispose();
    super.dispose();
  }

  void _stopScrolling() {
    _scrollToken += 1;
    _isScrolling = false;
    _lastDistance = 0;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _startScrolling(double distance) {
    if (distance <= 0) {
      _stopScrolling();
      return;
    }

    if (_isScrolling && (distance - _lastDistance).abs() < 0.5) {
      return;
    }

    _isScrolling = true;
    _lastDistance = distance;
    final token = ++_scrollToken;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollLoop(token, distance);
    });
  }

  Future<void> _scrollLoop(int token, double distance) async {
    final duration = _durationForDistance(distance);

    while (mounted && token == _scrollToken) {
      await Future.delayed(widget.pause);
      if (!mounted || token != _scrollToken) {
        break;
      }

      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          distance,
          duration: duration,
          curve: Curves.linear,
        );
      }

      await Future.delayed(widget.pause);
      if (!mounted || token != _scrollToken) {
        break;
      }

      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: duration,
          curve: Curves.linear,
        );
      }
    }
  }

  Duration _durationForDistance(double distance) {
    final ms = max(600, (distance / widget.velocity * 1000).round());
    return Duration(milliseconds: ms);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      _stopScrolling();
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(text: widget.text, style: widget.style);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();

        final maxWidth = constraints.maxWidth;
        if (textPainter.width <= maxWidth) {
          _stopScrolling();
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.textAlign,
          );
        }

        _startScrolling(textPainter.width - maxWidth);

        return ClipRect(
          child: SizedBox(
            height: textPainter.height,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        );
      },
    );
  }
}
