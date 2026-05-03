import "package:flutter/material.dart";
import "package:unimusic/components/lazy_image.dart";
import "package:unimusic/services/music_providers/music_provider.dart";
import "package:unimusic/views/pages/album_page.dart";

const albumCarouselCardHeight = 264.0;

class AlbumCarouselCard extends StatelessWidget {
  final Album album;
  final double? width;
  final double? height;

  const AlbumCarouselCard(this.album, {super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    Widget card = Semantics(
      button: true,
      label: "${album.name} by ${album.artists.formatted}",
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => AlbumPage.open(context, album),
          mouseCursor: SystemMouseCursors.click,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LazyImage(
                    artwork: album.artwork,
                    icon: Icon(LibraryItemType.albums.icon),
                    size: ArtworkSize.medium,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      album.artists.formatted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (width != null || height != null) {
      card = SizedBox(width: width, height: height, child: card);
    }
    return card;
  }
}
