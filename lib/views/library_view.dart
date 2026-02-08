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

class LibraryViewState extends State<LibraryView>
    with SingleTickerProviderStateMixin {
  late final TabController tabController;
  final Map<LibraryItemType, Completer<void>> _refreshCompleters = {};

  LibrarySortBy sortBy = LibrarySortBy.name;
  LibrarySortOrder sortOrder = LibrarySortOrder.ascending;
  Map<LibraryItemType, List<MusicItem>> libraryItems = {};
  MusicItem? currentItem;

  final Map<LibrarySortBy, String> _sortLabels = {
    LibrarySortBy.name: 'Name',
    LibrarySortBy.album: 'Album',
    LibrarySortBy.artist: 'Artist',
  };

  @override
  void initState() {
    tabController = TabController(
      vsync: this,
      length: LibraryItemType.values.length,
    );
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
    context.select(
      (MusicManager musicManager) => musicManager.providers.length,
    );

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
              if (libraryItems.isNotEmpty ||
                  snapshot.connectionState != ConnectionState.waiting) {
                final items = libraryItems[itemType];

                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                      top: 16,
                      bottom: safeAreaPadding.bottom + 48,
                    ),
                    itemCount: items?.length ?? 0,
                    itemBuilder: (context, index) {
                      final item = items![index];
                      return MusicItemTile(item);
                    },
                  ),
                );
              }

              return const Center(child: CircularProgressIndicator());
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

  Stream<void> _loadLibraryItems(
    BuildContext context,
    LibraryItemType itemType,
  ) async* {
    try {
      final musicManager = context.read<MusicManager>();
      libraryItems[itemType] = [];

      final items = musicManager.getLibraryItems(itemType: itemType);

      await for (final item in items) {
        libraryItems[itemType] ??= [];
        libraryItems[itemType]!.add(item);
        _sortItems(itemType);
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
      for (final itemType in LibraryItemType.values) {
        _sortItems(itemType);
      }
    });
  }

  Future<void> _changeSortBy() async {
    final itemType = LibraryItemType.values[tabController.index];
    final availableSorts = _availableSortBy(itemType);
    final selected = await showModalBottomSheet<LibrarySortBy>(
      useRootNavigator: true,
      showDragHandle: true,
      context: context,
      builder: (context) {
        return SafeArea(
          child: RadioGroup<LibrarySortBy>(
            groupValue: _effectiveSortBy(itemType),
            onChanged: (selected) {
              Navigator.pop(context, selected);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text('Sort by', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...availableSorts.map((value) {
                  return RadioListTile<LibrarySortBy>(
                    title: Text(_sortLabels[value] ?? value.name.capitalized),
                    value: value,
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (selected != null && selected != sortBy) {
      setState(() {
        sortBy = selected;
        for (final type in LibraryItemType.values) {
          _sortItems(type);
        }
      });
    }
  }

  void _sortItems(LibraryItemType itemType) {
    final items = libraryItems[itemType];
    if (items == null || items.isEmpty) return;

    final activeSortBy = _effectiveSortBy(itemType);

    items.sort((a, b) {
      final primary = _compareBySort(a, b, activeSortBy);
      if (primary != 0) {
        return primary * sortOrder.toInt();
      }
      return _nameKey(a).compareAlphabetically(_nameKey(b)) * sortOrder.toInt();
    });
  }

  LibrarySortBy _effectiveSortBy(LibraryItemType itemType) {
    final available = _availableSortBy(itemType);
    return available.contains(sortBy) ? sortBy : LibrarySortBy.name;
  }

  List<LibrarySortBy> _availableSortBy(LibraryItemType itemType) {
    return switch (itemType) {
      LibraryItemType.songs => [
        LibrarySortBy.name,
        LibrarySortBy.album,
        LibrarySortBy.artist,
      ],
      LibraryItemType.albums => [LibrarySortBy.name, LibrarySortBy.artist],
      LibraryItemType.artists => [LibrarySortBy.name],
    };
  }

  int _compareBySort(MusicItem a, MusicItem b, LibrarySortBy sortBy) {
    final keyA = _sortKey(a, sortBy);
    final keyB = _sortKey(b, sortBy);
    return keyA.compareAlphabetically(keyB);
  }

  String _sortKey(MusicItem item, LibrarySortBy sortBy) {
    return switch (sortBy) {
      LibrarySortBy.name => _nameKey(item),
      LibrarySortBy.album => _albumKey(item),
      LibrarySortBy.artist => _artistKey(item),
    };
  }

  String _nameKey(MusicItem item) {
    return switch (item) {
      Song song => song.name,
      Album album => album.name,
      Artist artist => artist.name,
      _ => '',
    };
  }

  String _albumKey(MusicItem item) {
    return switch (item) {
      Song song => song.album ?? '',
      Album album => album.name,
      Artist artist => artist.name,
      _ => '',
    };
  }

  String _artistKey(MusicItem item) {
    return switch (item) {
      Song song => song.artists.formatted,
      Album album => album.artists.formatted,
      Artist artist => artist.name,
      _ => '',
    };
  }
}
