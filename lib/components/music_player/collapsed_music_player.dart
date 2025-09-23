import 'package:flutter/material.dart';
import 'package:unimusic/components/lazy_image.dart';
import 'package:unimusic/services/music_manager.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:provider/provider.dart';

class CollapsedMusicPlayer extends StatelessWidget {
  final void Function()? onTap;
  const CollapsedMusicPlayer({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final musicManager = context.watch<MusicManager>();
    final currentItem = musicManager.currentItem;

    return ListTile(
      onTap: onTap,
      leading: currentItem == null
          ? Icon(Icons.music_off)
          : ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              child: LazyImage(
                icon: Icon(Icons.music_note),
                artwork: currentItem.artwork,
                width: 48,
              ),
            ),
      trailing: Wrap(
        spacing: -16,
        children: [
          IconButton(
            onPressed: musicManager.canSkipPrevious ? musicManager.skipPrevious : null,
            icon: Icon(Icons.skip_previous_rounded),
          ),
          IconButton(
            onPressed: musicManager.canPlay ? musicManager.togglePlayPause : null,
            icon: Icon(musicManager.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
          ),
          IconButton(
            onPressed: musicManager.canSkipNext ? musicManager.skipNext : null,
            icon: Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
      dense: true,
      title: Text(
        currentItem?.name ?? "No song is playing",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        currentItem?.artists.formatted ?? "Try playing something!",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
