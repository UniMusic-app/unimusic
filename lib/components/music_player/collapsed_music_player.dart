import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:unimusic/components/lazy_image.dart";
import "package:unimusic/components/playback_controls.dart";
import "package:unimusic/services/music_manager.dart";
import "package:unimusic/services/music_providers/music_provider.dart";
import "package:provider/provider.dart";

class CollapsedMusicPlayer extends StatelessWidget {
  final void Function()? onTap;

  const CollapsedMusicPlayer({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final musicManager = context.watch<MusicManager>();
    final currentItem = musicManager.currentItem;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    currentItem == null
                        ? const Icon(Symbols.music_off_rounded)
                        : ClipRRect(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(4),
                            ),
                            child: LazyImage(
                              icon: const Icon(Symbols.music_note_rounded),
                              artwork: currentItem.artwork,
                              width: 48,
                              size: ArtworkSize.small,
                            ),
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentItem?.name ?? "No song is playing",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            currentItem?.artists.formatted ??
                                "Try playing something!",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Controls intercept their own taps via the gesture arena
            const PlaybackControls(compact: true),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
