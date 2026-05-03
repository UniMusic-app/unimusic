import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:unimusic/components/favourite_button.dart";
import "package:unimusic/components/lazy_image.dart";
import "package:unimusic/components/music_player/views/audio_source_view.dart";
import "package:unimusic/components/playback_controls.dart";
import "package:unimusic/services/music_manager.dart";
import "package:unimusic/services/music_providers/music_provider.dart";
import "package:provider/provider.dart";

class DesktopCollapsedMusicPlayer extends StatelessWidget {
  final VoidCallback? onTap;

  const DesktopCollapsedMusicPlayer({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final musicManager = context.watch<MusicManager>();
    final currentItem = musicManager.currentItem;
    final theme = Theme.of(context);

    return SizedBox(
      height: 64,
      child: Row(
        children: [
          // --- Left: playback controls ---
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: PlaybackControls(
              iconSize: 20,
              playPauseIconSize: 28,
              compact: true,
            ),
          ),

          const SizedBox(width: 4),

          // --- Center: artwork + song info + favourite ---
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Artwork
                    if (currentItem != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LazyImage(
                          icon: const Icon(Symbols.music_note_rounded),
                          artwork: currentItem.artwork,
                          width: 44,
                          height: 44,
                          size: ArtworkSize.small,
                        ),
                      )
                    else
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Symbols.music_off_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                    const SizedBox(width: 12),

                    // Title + artist
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentItem?.name ?? "No song is playing",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
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

                    // Favourite button
                    if (currentItem != null)
                      FavouriteButton(
                        item: currentItem,
                        iconSize: 20,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // --- Right: audio output ---
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              iconSize: 20,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
              icon: const Icon(Symbols.speaker_rounded),
              tooltip: "Audio output",
              onPressed: () => AudioSourceView.show(context),
            ),
          ),
        ],
      ),
    );
  }
}
