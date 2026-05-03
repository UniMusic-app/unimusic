import "package:flutter/material.dart";
import "package:unimusic/components/favourite_button.dart";
import "package:unimusic/services/music_providers/music_provider.dart";
import "package:unimusic/utils/duration.dart";

class AlbumSongTile extends StatelessWidget {
  final Song song;
  final void Function()? onTap;
  final String? subtitle;

  const AlbumSongTile(this.song, {super.key, this.onTap, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final textTimeStyle = Theme.of(context).textTheme.labelSmall?.apply(
      fontFeatures: [const FontFeature.tabularFigures()],
    );

    return ListTile(
      onTap: onTap,
      dense: true,
      leading: song.trackNumber != null
          ? SizedBox(
              width: 32,
              child: Center(
                child: Text(
                  "${song.trackNumber}",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : null,
      title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle != null
          ? Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FavouriteButton(
            item: song,
            iconSize: 16,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
          const SizedBox(width: 8),
          Text(song.duration.formatted, style: textTimeStyle),
        ],
      ),
    );
  }
}
