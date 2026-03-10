import 'package:flutter/material.dart';
import 'package:unimusic/components/lazy_image.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/views/pages/album_page.dart';

const albumCarouselCardHeight = 264.0;

class AlbumCarouselCard extends StatelessWidget {
  final Album album;
  final double width;

  const AlbumCarouselCard(this.album, {super.key, this.width = 168});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: albumCarouselCardHeight,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => AlbumPage.open(context, album),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: LazyImage(
                  artwork: album.artwork,
                  icon: Icon(LibraryItemType.albums.icon),
                  size: ArtworkSize.medium,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        album.artists.formatted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
