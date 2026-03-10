import 'package:flutter/material.dart';
import 'package:unimusic/components/album_carousel_card.dart';
import 'package:unimusic/components/tiles/music_item_tile.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

class ArtistFavouritesPage extends StatelessWidget {
  final Artist artist;
  final List<Song> favouriteSongs;
  final List<Album> favouriteAlbums;

  const ArtistFavouritesPage({
    super.key,
    required this.artist,
    required this.favouriteSongs,
    required this.favouriteAlbums,
  });

  static void open(
    BuildContext context, {
    required Artist artist,
    required List<Song> favouriteSongs,
    required List<Album> favouriteAlbums,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtistFavouritesPage(
          artist: artist,
          favouriteSongs: favouriteSongs,
          favouriteAlbums: favouriteAlbums,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Favourites from ${artist.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: favouriteSongs.isEmpty && favouriteAlbums.isEmpty
          ? const _FavouritesEmptyState()
          : CustomScrollView(
              slivers: [
                if (favouriteAlbums.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Albums'),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: albumCarouselCardHeight,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: favouriteAlbums.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          return AlbumCarouselCard(favouriteAlbums[index]);
                        },
                      ),
                    ),
                  ),
                ],
                if (favouriteSongs.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(title: 'Songs'),
                  ),
                  SliverList.separated(
                    itemCount: favouriteSongs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final song = favouriteSongs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: MusicItemTile(
                          song,
                          contained: true,
                          containedPosition: switch (index) {
                            0 when favouriteSongs.length == 1 =>
                              ContainedTilePosition.single,
                            0 => ContainedTilePosition.first,
                            final i when i == favouriteSongs.length - 1 =>
                              ContainedTilePosition.last,
                            _ => ContainedTilePosition.middle,
                          },
                        ),
                      );
                    },
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _FavouritesEmptyState extends StatelessWidget {
  const _FavouritesEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded, size: 40),
            SizedBox(height: 12),
            Text(
              'No favourite songs or albums were found for this artist.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
