import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unimusic/components/tiles/music_item_tile.dart';
import 'package:unimusic/services/music_manager.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/utils/string.dart';
import 'package:provider/provider.dart';

class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => LibraryViewState();
}

class LibraryViewState extends State<LibraryView> with SingleTickerProviderStateMixin {
  late final TabController tabController;
  final Map<LibraryItemType, Completer<void>> _refreshCompleters = {};

  LibrarySortBy sortBy = LibrarySortBy.name;
  LibrarySortOrder sortOrder = LibrarySortOrder.ascending;
  Map<LibraryItemType, List<MusicItem>> libraryItems = {};
  MusicItem? currentItem;

  final sortingAlgorithms = {
    LibrarySortBy.name: (a, b) {
      return switch ((a, b)) {
        (Song a, Song b) => a.name.compareAlphabetically(b.name),
        (Album a, Album b) => a.name.compareAlphabetically(b.name),
        (Artist a, Artist b) => a.name.compareAlphabetically(b.name),
        (Album _, _) => -1,
        (Song _, _) => 0,
        _ => 1,
      };
    },
  };

  @override
  void initState() {
    tabController = TabController(vsync: this, length: LibraryItemType.values.length);
    super.initState();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for changes in music providers
    context.select((MusicManager musicManager) => musicManager.providers.length);

    final view = View.of(context);
    final safeAreaPadding = MediaQueryData.fromView(view).padding;

    return NestedScrollView(
      floatHeaderSlivers: true,
      headerSliverBuilder: (BuildContext context, _) {
        return [
          SliverAppBar(
            pinned: true,
            floating: true,
            stretch: true,
            snap: true,

            scrolledUnderElevation: 0,

            title: const Text("Library"),
            actions: [
              IconButton(
                onPressed: _changeSortOrder,
                icon: Icon(
                  sortOrder == LibrarySortOrder.ascending
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                ),
                tooltip: "Sort Order",
              ),
              IconButton(
                onPressed: _changeSortBy,
                icon: const Icon(Icons.sort_by_alpha),
                tooltip: "Sort By",
              ),
            ],

            bottom: TabBar(
              controller: tabController,
              tabs: LibraryItemType.values.map((itemType) {
                return Tab(text: itemType.name.capitalized);
              }).toList(),
            ),
          ),
        ];
      },

      body: TabBarView(
        controller: tabController,
        children: LibraryItemType.values.map((itemType) {
          return StreamBuilder(
            stream: _loadLibraryItems(context, itemType).asBroadcastStream(),
            builder: (context, snapshot) {
              if (libraryItems.isNotEmpty || snapshot.connectionState != ConnectionState.waiting) {
                final items = libraryItems[itemType];

                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: ListView.builder(
                    padding: EdgeInsets.only(top: 16, bottom: safeAreaPadding.bottom + 48),
                    itemCount: items?.length ?? 0,
                    itemBuilder: (context, index) {
                      final item = items![index];
                      return MusicItemTile(item);
                    },
                  ),
                );
              }

              return const Center(child: CircularProgressIndicator(year2023: false));
            },
          );
        }).toList(),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final itemType = LibraryItemType.values[tabController.index];
    _refreshCompleters[itemType] = Completer<void>();
    setState(() {
      // This will rebuild the StreamBuilder with a new stream.
    });
    return _refreshCompleters[itemType]!.future;
  }

  Stream<void> _loadLibraryItems(BuildContext context, LibraryItemType itemType) async* {
    try {
      final musicManager = context.read<MusicManager>();
      libraryItems[itemType] = [];

      final items = musicManager.getLibraryItems(itemType: itemType);

      await for (final item in items) {
        libraryItems[itemType] ??= [];
        libraryItems[itemType]!.add(item);
        libraryItems[itemType]!.sort((a, b) {
          return sortingAlgorithms[LibrarySortBy.name]!(a, b) * sortOrder.toInt();
        });
        yield null;
      }
    } finally {
      _refreshCompleters[itemType]?.complete();
      _refreshCompleters.remove(itemType);
    }
  }

  void _changeSortOrder() {
    setState(() {
      sortOrder = LibrarySortOrder.fromInt(sortOrder.toInt() * -1);
    });
  }

  Future<void> _changeSortBy() async {
    await showModalBottomSheet(
      useRootNavigator: true,
      showDragHandle: true,
      context: context,
      builder: (context) {
        return SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Modal BottomSheet'),
                ElevatedButton(
                  child: const Text('Close BottomSheet'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
