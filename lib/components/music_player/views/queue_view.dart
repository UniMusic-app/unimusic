import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unimusic/components/adaptive_context_menu.dart';
import 'package:unimusic/components/tiles/music_item_tile.dart';
import 'package:unimusic/services/music_manager.dart';

class MusicQueueView extends StatelessWidget {
  const MusicQueueView({super.key});

  @override
  Widget build(BuildContext context) {
    final musicManager = context.watch<MusicManager>();

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: [
          Text("Queue", style: Theme.of(context).textTheme.titleSmall),
          Expanded(
            child: Material(
              clipBehavior: Clip.hardEdge,
              color: Colors.transparent,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.05, 0.95, 1.0],
                  ).createShader(bounds);
                },
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  itemCount: musicManager.queue.length,
                  itemBuilder: (context, index) {
                    final song = musicManager.queue[index];
                    final color = index == musicManager.queuePosition
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.surfaceContainerHigh;

                    return Material(
                      key: ValueKey(index),
                      color: color,
                      child: InkWell(
                        child: MusicItemTile(
                          song,
                          action: TileAction(
                            text: "Select track",
                            icon: Icons.queue_play_next,
                            onTap: () => musicManager.jumpToQueueItem(index),
                          ),
                          menuItems: [
                            MenuAction(
                              title: "Remove from queue",
                              icon: Icons.delete_outline,
                              onTap: () => musicManager.removeFromQueue(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    musicManager.reorderQueue(oldIndex, newIndex);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
