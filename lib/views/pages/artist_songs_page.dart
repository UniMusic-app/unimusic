import 'package:flutter/material.dart';
import 'package:unimusic/components/tiles/music_item_tile.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

class ArtistSongsPage extends StatefulWidget {
  final Artist artist;

  const ArtistSongsPage({super.key, required this.artist});

  static void open(BuildContext context, Artist artist) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ArtistSongsPage(artist: artist)),
    );
  }

  @override
  State<ArtistSongsPage> createState() => _ArtistSongsPageState();
}

class _ArtistSongsPageState extends State<ArtistSongsPage> {
  static const int _pageSize = 25;

  final ScrollController _scrollController = ScrollController();
  final List<Song> _songs = [];

  bool _isInitialLoad = true;
  bool _isLoadingMore = false;
  bool _hasMoreSongs = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadMoreSongs();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMoreSongs) {
      return;
    }

    if (_scrollController.position.extentAfter < 320) {
      _loadMoreSongs();
    }
  }

  Future<void> _loadMoreSongs() async {
    if (_isLoadingMore || !_hasMoreSongs) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final nextSongs = await widget.artist
          .getFeaturedSongs(limit: _pageSize, startIndex: _songs.length)
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _songs.addAll(nextSongs);
        _hasMoreSongs = nextSongs.length == _pageSize;
        _isInitialLoad = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Failed to load songs.';
        _isInitialLoad = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.artist.name} Songs',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: switch ((_isInitialLoad, _songs.isEmpty, _errorMessage)) {
        (true, true, _) => const Center(child: CircularProgressIndicator()),
        (_, true, final String error) => _SongsPageStateView(
          icon: Icons.error_outline_rounded,
          message: error,
          actionLabel: 'Retry',
          onAction: _loadMoreSongs,
        ),
        (_, true, _) => const _SongsPageStateView(
          icon: Icons.library_music_outlined,
          message: 'No songs available for this artist.',
        ),
        _ => ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
          itemCount:
              _songs.length + (_hasMoreSongs || _errorMessage != null ? 1 : 0),
          separatorBuilder: (_, index) => index >= _songs.length - 1
              ? const SizedBox.shrink()
              : const SizedBox(height: 4),
          itemBuilder: (context, index) {
            if (index >= _songs.length) {
              if (_errorMessage != null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.tonalIcon(
                    onPressed: _loadMoreSongs,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry loading more'),
                  ),
                );
              }

              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final song = _songs[index];
            return MusicItemTile(song);
          },
        ),
      },
    );
  }
}

class _SongsPageStateView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _SongsPageStateView({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
