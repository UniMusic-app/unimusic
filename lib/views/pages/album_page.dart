import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unimusic/components/lazy_image.dart';
import 'package:unimusic/components/tiles/album_song_tile.dart';
import 'package:unimusic/services/music_manager.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

class AlbumPage extends StatefulWidget {
  final Album album;

  const AlbumPage(this.album, {super.key});

  static open(BuildContext context, Album album) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AlbumPage(album)));
  }

  static openAsync(BuildContext context, Future<Album?> futureAlbum) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FutureBuilder<Album?>(
          future: futureAlbum,
          builder: (context, snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('Loading album information...'),
                      ],
                    ),
                  ),
                );
              case ConnectionState.done:
                if (snapshot.hasData && snapshot.data != null) {
                  return AlbumPage(snapshot.data!);
                } else {
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text('Album not found.', style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    ),
                  );
                }
              case ConnectionState.active:
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('Loading album...'),
                      ],
                    ),
                  ),
                );
            }
          },
        ),
      ),
    );
  }

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  List<Song>? _songs;
  final ScrollController _scrollController = ScrollController();
  bool _showTitleInAppBar = false;
  bool _isLoadingSongs = false;
  String _loadingMessage = 'Loading songs...';

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _scrollController.addListener(_scrollListener);
  }

  void _loadSongs() {
    setState(() {
      _isLoadingSongs = true;
    });

    widget.album
        .getSongs()
        .toList()
        .then((songs) {
          if (mounted) {
            setState(() {
              _songs = songs;
              _isLoadingSongs = false;
              _loadingMessage = '';
            });
          }
        })
        .catchError((_) {
          if (mounted) {
            setState(() {
              _isLoadingSongs = false;
              _loadingMessage = 'Failed to load songs.';
            });
          }
        });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final showTitle = _scrollController.offset > 64;
    if (showTitle != _showTitleInAppBar) {
      setState(() {
        _showTitleInAppBar = showTitle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final musicManager = context.read<MusicManager>();

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            title: AnimatedOpacity(
              opacity: _showTitleInAppBar ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Text(widget.album.name, maxLines: 1),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.album.artwork != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LazyImage(
                        artwork: widget.album.artwork!,
                        icon: Icon(LibraryItemType.albums.icon),
                        width: 150,
                        size: ArtworkSize.medium,
                      ),
                    ),
                  if (widget.album.artwork != null) const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: widget.album.artwork != null ? 150 : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.album.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            widget.album.artists.formatted,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (widget.album.artwork != null) const Spacer(),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.play_arrow),
                              label: const Text("Play"),
                              onPressed: _songs == null || _isLoadingSongs
                                  ? null
                                  : () async {
                                      await musicManager.clearQueue();
                                      await musicManager.queueSongs(_songs!);
                                      await musicManager.play();
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoadingSongs && _songs == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(_loadingMessage, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            )
          else if (_songs == null || _songs!.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_songs?.isEmpty == true)
                        const Text('No songs in this album.')
                      else if (_loadingMessage.isNotEmpty)
                        Text(_loadingMessage)
                      else
                        const Text('Loading songs...'),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: _songs!.length,
              itemBuilder: (context, index) {
                final song = _songs![index];
                return AlbumSongTile(
                  song,
                  onTap: () async {
                    await musicManager.queueSong(song);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
