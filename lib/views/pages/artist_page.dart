import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:provider/provider.dart";
import "package:unimusic/components/album_carousel_card.dart";
import "package:unimusic/components/empty_state_view.dart";
import "package:unimusic/components/lazy_image.dart";
import "package:unimusic/components/tiles/music_item_tile.dart";
import "package:unimusic/services/music_manager.dart";
import "package:unimusic/services/music_providers/music_provider.dart";
import "package:unimusic/views/pages/artist_favourites_page.dart";
import "package:unimusic/views/pages/artist_songs_page.dart";

class ArtistPage extends StatefulWidget {
  final Artist artist;

  const ArtistPage({super.key, required this.artist});

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  static const int _highlightedSongsLimit = 5;

  final ScrollController _scrollController = ScrollController();
  List<Song> _highlightedSongs = [];
  bool _showTitleInAppBar = false;
  bool _isLoadingHighlightedSongs = true;
  bool _isQueueingArtist = false;
  bool _isShuffleQueueingArtist = false;
  String? _highlightedSongsError;
  Future<_ArtistFavouritesData>? _favouritesFuture;
  late final Future<Artwork?> _artistArtworkFuture;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _artistArtworkFuture = widget.artist.getArtwork();
    _loadHighlightedSongs();
    _refreshFavourites();
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

  Future<void> _loadHighlightedSongs() async {
    setState(() {
      _isLoadingHighlightedSongs = true;
      _highlightedSongsError = null;
    });

    try {
      final songs = await widget.artist
          .getFeaturedSongs(limit: _highlightedSongsLimit)
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _highlightedSongs = songs;
        _isLoadingHighlightedSongs = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _highlightedSongsError = "Failed to load songs.";
        _isLoadingHighlightedSongs = false;
      });
    }
  }

  void _refreshFavourites() {
    setState(() {
      _favouritesFuture = _loadFavourites();
    });
  }

  Future<_ArtistFavouritesData> _loadFavourites() async {
    final favourites = await widget.artist.getFavourites().toList();

    final favouriteSongs = favourites.whereType<Song>().toList();
    final favouriteAlbums = favourites.whereType<Album>().toList();

    return _ArtistFavouritesData(
      favouriteSongs: favouriteSongs,
      favouriteAlbums: favouriteAlbums,
    );
  }

  Future<bool> _startArtistPlayback({required bool shuffle}) async {
    final musicManager = context.read<MusicManager>();

    await musicManager.clearQueue();
    await musicManager.setShuffleModeEnabled(shuffle, reshuffle: false);
    await musicManager.queueSongStream(widget.artist.getFeaturedSongs());

    if (musicManager.queue.isEmpty) {
      return false;
    }

    await musicManager.play();
    return true;
  }

  Future<void> _playArtist() async {
    if (_isQueueingArtist || _isShuffleQueueingArtist) {
      return;
    }

    setState(() {
      _isQueueingArtist = true;
    });

    try {
      final didStartPlayback = await _startArtistPlayback(shuffle: false);

      if (!didStartPlayback && mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No songs available for this artist."),
            ),
          );
        }

        return;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to load songs for this artist."),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isQueueingArtist = false;
        });
      }
    }
  }

  Future<void> _shuffleArtist() async {
    if (_isQueueingArtist || _isShuffleQueueingArtist) {
      return;
    }

    setState(() {
      _isShuffleQueueingArtist = true;
    });

    try {
      final didQueueSongs = await _startArtistPlayback(shuffle: true);

      if (!didQueueSongs && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No songs available for this artist.")),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to load songs for this artist."),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isShuffleQueueingArtist = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showSongsSection =
        _isLoadingHighlightedSongs ||
        _highlightedSongsError != null ||
        _highlightedSongs.isNotEmpty;

    return Material(
      color: theme.colorScheme.surface,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            title: AnimatedOpacity(
              opacity: _showTitleInAppBar ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Text(widget.artist.name, maxLines: 1),
            ),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<Artwork?>(
              future: _artistArtworkFuture,
              builder: (context, snapshot) {
                final artworkData = snapshot.data ?? widget.artist.artwork;

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 560;
                      final artwork = artworkData == null
                          ? null
                          : ClipOval(
                              child: LazyImage(
                                artwork: artworkData,
                                icon: Icon(LibraryItemType.artists.icon),
                                width: 150,
                                height: 150,
                                size: ArtworkSize.medium,
                              ),
                            );

                      final playButton = FilledButton.icon(
                        onPressed: _isQueueingArtist || _isShuffleQueueingArtist
                            ? null
                            : _playArtist,
                        icon: _isQueueingArtist
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Symbols.play_arrow_rounded),
                        label: const Text("Play"),
                      );

                      final shuffleButton = OutlinedButton.icon(
                        onPressed: _isQueueingArtist || _isShuffleQueueingArtist
                            ? null
                            : _shuffleArtist,
                        icon: _isShuffleQueueingArtist
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Symbols.shuffle_rounded),
                        label: const Text("Shuffle"),
                      );

                      final actionButtons = Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: compact
                            ? WrapAlignment.center
                            : WrapAlignment.start,
                        children: [playButton, shuffleButton],
                      );

                      final content = compact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  widget.artist.name,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 16),
                                actionButtons,
                              ],
                            )
                          : SizedBox(
                              height: artwork != null ? 150 : null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.artist.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.headlineMedium,
                                  ),
                                  if (artwork != null) const Spacer(),
                                  Align(
                                    alignment: Alignment.bottomLeft,
                                    child: actionButtons,
                                  ),
                                ],
                              ),
                            );

                      if (compact) {
                        return Column(
                          children: [
                            if (artwork != null) artwork,
                            if (artwork != null) const SizedBox(height: 16),
                            content,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (artwork != null) artwork,
                          if (artwork != null) const SizedBox(width: 16),
                          Expanded(child: content),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<_ArtistFavouritesData>(
              future: _favouritesFuture,
              builder: (context, snapshot) {
                final data = snapshot.data;
                final hasAnyFavourites = data?.hasAny ?? false;
                final canOpenFavourites =
                    snapshot.connectionState == ConnectionState.done &&
                    hasAnyFavourites;

                final subtitle = switch (snapshot.connectionState) {
                  ConnectionState.done when data != null => _favouritesSubtitle(
                    data,
                  ),
                  ConnectionState.done when snapshot.hasError =>
                    "Could not load favourites.",
                  _ => "Loading favourites...",
                };

                return Column(
                  children: [
                    const _SectionHeader(title: "Your favourites"),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: ListTile(
                          enabled: canOpenFavourites,
                          onTap: !canOpenFavourites
                              ? null
                              : () {
                                  final favourites = data!;
                                  ArtistFavouritesPage.open(
                                    context,
                                    artist: widget.artist,
                                    favouriteSongs: favourites.favouriteSongs,
                                    favouriteAlbums: favourites.favouriteAlbums,
                                  );
                                },
                          leading: Icon(
                            Symbols.favorite_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          title: const Text("Your favourites"),
                          subtitle: Text(subtitle),
                          trailing:
                              snapshot.connectionState != ConnectionState.done
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : snapshot.hasError
                              ? IconButton(
                                  onPressed: _refreshFavourites,
                                  icon: const Icon(Symbols.refresh_rounded),
                                )
                              : canOpenFavourites
                              ? const Icon(Symbols.chevron_right_rounded)
                              : null,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (showSongsSection) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: "Featured Songs",
                actionLabel: "View all",
                onAction: () => ArtistSongsPage.open(context, widget.artist),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ArtistSongsPreview(
                  songs: _highlightedSongs,
                  isLoading: _isLoadingHighlightedSongs,
                  errorMessage: _highlightedSongsError,
                  onRetry: _loadHighlightedSongs,
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: _ArtistAlbumsSection(artist: widget.artist),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _ArtistFavouritesData {
  final List<Song> favouriteSongs;
  final List<Album> favouriteAlbums;

  const _ArtistFavouritesData({
    required this.favouriteSongs,
    required this.favouriteAlbums,
  });

  bool get hasAny => favouriteSongs.isNotEmpty || favouriteAlbums.isNotEmpty;
}

String _favouritesSubtitle(_ArtistFavouritesData data) {
  if (!data.hasAny) {
    return "You do not have any favourites from this artist.";
  }

  final tracks =
      '${data.favouriteSongs.length} ${data.favouriteSongs.length == 1 ? 'track' : 'tracks'}';
  if (data.favouriteAlbums.isEmpty) {
    return tracks;
  }

  final albums =
      '${data.favouriteAlbums.length} ${data.favouriteAlbums.length == 1 ? 'album' : 'albums'}';
  return "$tracks · $albums";
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _ArtistSongsPreview extends StatelessWidget {
  final List<Song> songs;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRetry;

  const _ArtistSongsPreview({
    required this.songs,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: EmptyStateView(
            icon: Symbols.music_note_rounded,
            message: "Loading songs...",
            iconSize: 32,
            action: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: EmptyStateView(
            icon: Symbols.error_outline_rounded,
            message: errorMessage!,
            iconSize: 32,
            action: FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Symbols.refresh_rounded),
              label: const Text("Retry"),
            ),
          ),
        ),
      );
    }

    if (songs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (var index = 0; index < songs.length; index++) ...[
          if (index > 0) const SizedBox(height: 4),
          MusicItemTile(
            songs[index],
            contained: true,
            containedPosition: _containedTilePosition(index, songs.length),
          ),
        ],
      ],
    );
  }
}

ContainedTilePosition _containedTilePosition(int index, int total) {
  if (total <= 1) {
    return ContainedTilePosition.single;
  }
  if (index == 0) {
    return ContainedTilePosition.first;
  }
  if (index == total - 1) {
    return ContainedTilePosition.last;
  }
  return ContainedTilePosition.middle;
}

class _ArtistAlbumsSection extends StatefulWidget {
  final Artist artist;

  const _ArtistAlbumsSection({required this.artist});

  @override
  State<_ArtistAlbumsSection> createState() => _ArtistAlbumsSectionState();
}

class _ArtistAlbumsSectionState extends State<_ArtistAlbumsSection> {
  static const int _pageSize = 12;

  final ScrollController _scrollController = ScrollController();
  final List<Album> _albums = [];

  bool _isInitialLoad = true;
  bool _isLoadingMore = false;
  bool _hasMoreAlbums = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadMoreAlbums();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients ||
        _isLoadingMore ||
        !_hasMoreAlbums ||
        _errorMessage != null) {
      return;
    }

    if (_scrollController.position.extentAfter < 320) {
      _loadMoreAlbums();
    }
  }

  Future<void> _loadMoreAlbums() async {
    if (_isLoadingMore || !_hasMoreAlbums) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final nextAlbums = await widget.artist
          .getAlbums(limit: _pageSize, startIndex: _albums.length)
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _albums.addAll(nextAlbums);
        _hasMoreAlbums = nextAlbums.length == _pageSize;
        _isInitialLoad = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = "Failed to load albums.";
        _isInitialLoad = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoad && _albums.isEmpty) {
      return const Column(
        children: [
          _SectionHeader(title: "Albums"),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: EmptyStateView(
                  icon: Symbols.album_rounded,
                  message: "Loading albums...",
                  iconSize: 32,
                  action: CircularProgressIndicator(),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null && _albums.isEmpty) {
      return Column(
        children: [
          const _SectionHeader(title: "Albums"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: EmptyStateView(
                  icon: Symbols.error_outline_rounded,
                  message: _errorMessage!,
                  iconSize: 32,
                  action: FilledButton.tonalIcon(
                    onPressed: _loadMoreAlbums,
                    icon: const Icon(Symbols.refresh_rounded),
                    label: const Text("Retry"),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_albums.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const _SectionHeader(title: "Albums"),
        SizedBox(
          height: albumCarouselCardHeight,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount:
                _albums.length +
                (_hasMoreAlbums || _errorMessage != null ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index >= _albums.length) {
                return SizedBox(
                  width: 96,
                  child: Center(
                    child: _errorMessage != null
                        ? FilledButton.tonalIcon(
                            onPressed: _loadMoreAlbums,
                            icon: const Icon(Symbols.refresh_rounded),
                            label: const Text("Retry"),
                          )
                        : const CircularProgressIndicator(),
                  ),
                );
              }

              return AlbumCarouselCard(
                _albums[index],
                width: 168,
                height: albumCarouselCardHeight,
              );
            },
          ),
        ),
      ],
    );
  }
}
