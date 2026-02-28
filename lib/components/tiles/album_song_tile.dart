import 'package:flutter/material.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/utils/duration.dart';

class AlbumSongTile extends StatefulWidget {
  final Song song;
  final void Function()? onTap;

  const AlbumSongTile(this.song, {super.key, this.onTap});

  @override
  State<AlbumSongTile> createState() => _AlbumSongTileState();
}

class _AlbumSongTileState extends State<AlbumSongTile> {
  void _toggleFavourite() async {
    await widget.song.toggleFavourite(!widget.song.favourite);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(AlbumSongTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.favourite != widget.song.favourite) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTimeStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.apply(fontFeatures: [FontFeature.tabularFigures()]);

    return ListTile(
      onTap: widget.onTap,
      dense: true,
      title: Text(
        widget.song.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: widget.song.favourite
                ? Icon(
                    Icons.favorite_rounded,
                    color: Colors.pinkAccent,
                    size: 16,
                  )
                : Icon(
                    Icons.favorite_outline_rounded,
                    color: Colors.grey,
                    size: 16,
                  ),
            onPressed: _toggleFavourite,
          ),
          const SizedBox(width: 8),
          Text(widget.song.duration.formatted, style: textTimeStyle),
        ],
      ),
    );
  }
}
