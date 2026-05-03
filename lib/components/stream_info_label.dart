import "package:flutter/material.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class StreamInfoLabel extends StatefulWidget {
  final Song? song;
  final TextStyle? style;

  const StreamInfoLabel({super.key, required this.song, this.style});

  @override
  State<StreamInfoLabel> createState() => _StreamInfoLabelState();
}

class _StreamInfoLabelState extends State<StreamInfoLabel> {
  Future<String?>? _labelFuture;
  String? _songKey;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _updateFuture();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StreamInfoLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey = _makeSongKey(widget.song);
    if (_songKey != newKey) {
      _updateFuture();
    }
  }

  void _updateFuture() {
    _songKey = _makeSongKey(widget.song);
    _labelFuture = _buildLabel(widget.song);
  }

  Future<String?> _buildLabel(Song? song) async {
    if (song == null) return null;

    final parts = await song.getStreamInfoParts();
    if (_disposed) return null;

    return _formatLabel(song.providerId, parts);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _labelFuture,
      builder: (context, snapshot) {
        final label = snapshot.data;
        if (label == null || label.isEmpty) {
          return const SizedBox.shrink();
        }

        return AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            label,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}

String? _makeSongKey(Song? song) {
  if (song == null) return null;
  return "${song.providerId}:${song.id}";
}

String? _formatLabel(String providerId, StreamInfoParts? parts) {
  final provider = _providerLabel(providerId);
  if (parts == null) return provider;

  final segments = <String>[];
  if (parts.format != null && parts.format!.isNotEmpty) {
    segments.add(parts.format!);
  }
  if (parts.bitrateKbps != null && parts.bitrateKbps! > 0) {
    segments.add("${parts.bitrateKbps} kbps");
  }
  if (parts.sampleRateHz != null && parts.sampleRateHz! > 0) {
    segments.add(_formatSampleRate(parts.sampleRateHz!));
  }

  if (segments.isEmpty) return provider;
  return "$provider - ${segments.join(" ")}";
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

String _formatSampleRate(int sampleRateHz) {
  final khz = sampleRateHz / 1000;
  final rounded = khz.roundToDouble();
  final label = (khz - rounded).abs() < 0.05
      ? rounded.toStringAsFixed(0)
      : khz.toStringAsFixed(1);
  return "$label kHz";
}
