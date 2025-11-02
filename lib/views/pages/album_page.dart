import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unimusic/components/lazy_image.dart';
import 'package:unimusic/components/album_song_tile.dart';
import 'package:unimusic/services/music_manager.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

class AlbumPage extends StatefulWidget {
  final Album album;

  const AlbumPage({super.key, required this.album});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  List<Song>? _songs;
  final ScrollController _scrollController = ScrollController();
  bool _showTitleInAppBar = false;

  @override
  void initState() {
    super.initState();
    widget.album.getSongs().toList().then((songs) {
      if (mounted) {
        setState(() {
          _songs = songs;
        });
      }
    });
    _scrollController.addListener(_scrollListener);
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
              child: Text(widget.album.name),
            ),
          ),
          if (_songs == null)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_songs!.isEmpty)
            const SliverFillRemaining(child: Center(child: Text('No songs in this album.')))
          else ...[
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
                                onPressed: () async {
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
            SliverList.builder(
              itemCount: _songs!.length,
              itemBuilder: (context, index) {
                final song = _songs![index];
                return AlbumSongTile(
                  song: song,
                  onTap: () async {
                    await musicManager.queueSong(song);
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
