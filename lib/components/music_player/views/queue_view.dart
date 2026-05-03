import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:provider/provider.dart";
import "package:unimusic/components/adaptive_context_menu.dart";
import "package:unimusic/components/tiles/music_item_tile.dart";
import "package:unimusic/services/music_manager.dart";

class MusicQueueView extends StatefulWidget {
  const MusicQueueView({super.key});

  @override
  State<MusicQueueView> createState() => _MusicQueueViewState();
}

class _MusicQueueViewState extends State<MusicQueueView> {
  static const _fadeThreshold = 48.0;

  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final musicManager = context.watch<MusicManager>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          Text("Queue", style: Theme.of(context).textTheme.titleSmall),
          Expanded(
            child: Material(
              clipBehavior: Clip.hardEdge,
              color: Colors.transparent,
              // ListenableBuilder rebuilds only the ShaderMask on scroll events.
              // The list is passed as child so it is not rebuilt every frame.
              child: ListenableBuilder(
                listenable: _scrollController,
                child: ReorderableListView.builder(
                  scrollController: _scrollController,
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
                        mouseCursor: SystemMouseCursors.click,
                        child: MusicItemTile(
                          song,
                          action: TileAction(
                            text: "Select track",
                            icon: Symbols.queue_play_next_rounded,
                            onTap: () => musicManager.jumpToQueueItem(index),
                          ),
                          menuItems: [
                            MenuAction(
                              title: "Remove from queue",
                              icon: Symbols.delete_outline_rounded,
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
                builder: (context, child) {
                  double topStop = 0.0;
                  double bottomStop = 0.95;

                  if (_scrollController.hasClients) {
                    final position = _scrollController.position;
                    topStop =
                        (position.pixels / _fadeThreshold).clamp(0.0, 1.0) *
                        0.05;
                    bottomStop =
                        1.0 -
                        ((position.maxScrollExtent - position.pixels) /
                                    _fadeThreshold)
                                .clamp(0.0, 1.0) *
                            0.05;
                  }

                  return ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: const [
                          Colors.transparent,
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0.0, topStop, bottomStop, 1.0],
                      ).createShader(bounds);
                    },
                    child: child,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
