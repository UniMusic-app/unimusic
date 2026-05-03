import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:provider/provider.dart";
import "package:unimusic/components/lazy_image.dart";
import "package:unimusic/components/tiles/album_song_tile.dart";
import "package:unimusic/services/music_manager.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class AlbumPage extends StatefulWidget {
  final Album album;

  const AlbumPage(this.album, {super.key});

  static void open(BuildContext context, Album album) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AlbumPage(album)),
    );
  }

  static void openAsync(BuildContext context, Future<Album?> futureAlbum) {
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
                  appBar: AppBar(),
                  body: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Loading album information..."),
                      ],
                    ),
                  ),
                );
              case ConnectionState.done:
                if (snapshot.hasData && snapshot.data != null) {
                  return AlbumPage(snapshot.data!);
                } else {
                  return Scaffold(
                    appBar: AppBar(),
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Symbols.error_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Album not found.",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                }
              case ConnectionState.active:
                return Scaffold(
                  appBar: AppBar(),
                  body: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Loading album..."),
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
  String _loadingMessage = "Loading songs...";

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
            songs.sort((a, b) {
              final discA = a.discNumber ?? 1;
              final discB = b.discNumber ?? 1;
              if (discA != discB) {
                return discA.compareTo(discB);
              }

              final trackA = a.trackNumber ?? 9999;
              final trackB = b.trackNumber ?? 9999;
              return trackA.compareTo(trackB);
            });

            setState(() {
              _songs = songs;
              _isLoadingSongs = false;
              _loadingMessage = "";
            });
          }
        })
        .catchError((_) {
          if (mounted) {
            setState(() {
              _isLoadingSongs = false;
              _loadingMessage = "Failed to load songs.";
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
      color: Theme.of(context).colorScheme.surface,
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
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            widget.album.artists.formatted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (widget.album.artwork != null) const Spacer(),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: FilledButton.icon(
                              icon: const Icon(Symbols.play_arrow_rounded),
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
                      Text(
                        _loadingMessage,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
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
                        const Text("No songs in this album.")
                      else if (_loadingMessage.isNotEmpty)
                        Text(_loadingMessage)
                      else
                        const Text("Loading songs..."),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._buildSongList(musicManager),
        ],
      ),
    );
  }

  List<Widget> _buildSongList(MusicManager musicManager) {
    if (_songs == null || _songs!.isEmpty) return [];

    final songsByDisc = <int, List<Song>>{};
    for (final song in _songs!) {
      final disc = song.discNumber ?? 1;
      songsByDisc.putIfAbsent(disc, () => []).add(song);
    }

    final discNumbers = songsByDisc.keys.toList()..sort();
    final hasMultipleDiscs = discNumbers.length > 1;

    final widgets = <Widget>[];
    for (final discNumber in discNumbers) {
      final discSongs = songsByDisc[discNumber]!;

      if (hasMultipleDiscs) {
        widgets.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "Disc $discNumber",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        );
      }

      widgets.add(
        SliverList.builder(
          itemCount: discSongs.length,
          itemBuilder: (context, index) {
            final song = discSongs[index];
            return AlbumSongTile(
              song,
              onTap: () async {
                await musicManager.queueSong(song);
              },
            );
          },
        ),
      );
    }

    return widgets;
  }
}
