import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unimusic/components/library_filter_button.dart';
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
  LibraryFilters filters = const LibraryFilters();
  Map<LibraryItemType, List<MusicItem>> libraryItems = {};

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
    final musicManager = context.watch<MusicManager>();
    final availableProviderIds = musicManager.providers
        .map((provider) => provider.id)
        .toSet();

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
              LibraryFilterButton(
                filters: filters,
                providers: musicManager.providers,
                onChanged: (nextFilters) {
                  setState(() {
                    filters = nextFilters;
                  });
                },
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
              final filteredItems = _filteredItems(
                itemType,
                availableProviderIds,
              );
              final hasActiveFilters =
                  filters.textFilterCount > 0 ||
                  filters.providerIds
                      .intersection(availableProviderIds)
                      .isNotEmpty;
              final isStillLoading =
                  filteredItems.isEmpty &&
                  snapshot.connectionState != ConnectionState.done;

              if (isStillLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final showEmptyState = filteredItems.isEmpty;

              return RefreshIndicator(
                onRefresh: _handleRefresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: 16,
                    bottom: safeAreaPadding.bottom + 48,
                  ),
                  itemCount: showEmptyState ? 1 : filteredItems.length,
                  itemBuilder: (context, index) {
                    if (showEmptyState) {
                      return _EmptyLibraryState(
                        itemType: itemType,
                        hasActiveFilters: hasActiveFilters,
                      );
                    }

                    final item = filteredItems[index];
                    return MusicItemTile(item);
                  },
                ),
              );
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
        _insertSorted(itemType, item);
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

  void _insertSorted(LibraryItemType itemType, MusicItem item) {
    final items = libraryItems[itemType]!;
    final activeSortBy = _effectiveSortBy(itemType);

    // Binary search to find insertion point
    int low = 0;
    int high = items.length;

    while (low < high) {
      final mid = (low + high) ~/ 2;
      final comparison = _compareItems(item, items[mid], activeSortBy);

      if (comparison < 0) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }

    items.insert(low, item);
  }

  int _compareItems(MusicItem a, MusicItem b, LibrarySortBy activeSortBy) {
    final primary = _compareBySort(a, b, activeSortBy);
    if (primary != 0) {
      return primary * sortOrder.toInt();
    }
    return _nameKey(a).compareAlphabetically(_nameKey(b)) * sortOrder.toInt();
  }

  void _sortItems(LibraryItemType itemType) {
    final items = libraryItems[itemType];
    if (items == null || items.isEmpty) return;

    final activeSortBy = _effectiveSortBy(itemType);

    items.sort((a, b) => _compareItems(a, b, activeSortBy));
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

  List<MusicItem> _filteredItems(
    LibraryItemType itemType,
    Set<String> availableProviderIds,
  ) {
    final items = libraryItems[itemType] ?? const <MusicItem>[];

    return items
        .where((item) => _matchesFilters(item, availableProviderIds))
        .toList(growable: false);
  }

  bool _matchesFilters(MusicItem item, Set<String> availableProviderIds) {
    final selectedProviderIds = filters.providerIds.intersection(
      availableProviderIds,
    );

    if (selectedProviderIds.isNotEmpty &&
        !selectedProviderIds.contains(item.providerId)) {
      return false;
    }

    final titleQuery = filters.titleQuery.trim().toLowerCase();
    final albumQuery = filters.albumQuery.trim().toLowerCase();
    final artistQuery = filters.artistQuery.trim().toLowerCase();

    return switch (item) {
      Song song =>
        _matchesText(song.name, titleQuery) &&
            _matchesText(song.album ?? '', albumQuery) &&
            _matchesText(song.artists.formatted, artistQuery),
      Album album =>
        titleQuery.isEmpty &&
            _matchesText(album.name, albumQuery) &&
            _matchesText(album.artists.formatted, artistQuery),
      Artist artist =>
        titleQuery.isEmpty &&
            albumQuery.isEmpty &&
            _matchesText(artist.name, artistQuery),
      _ => true,
    };
  }

  bool _matchesText(String source, String query) {
    if (query.isEmpty) return true;
    return source.toLowerCase().contains(query);
  }
}

class _EmptyLibraryState extends StatelessWidget {
  final LibraryItemType itemType;
  final bool hasActiveFilters;

  const _EmptyLibraryState({
    required this.itemType,
    required this.hasActiveFilters,
  });

  @override
  Widget build(BuildContext context) {
    final description = hasActiveFilters
        ? 'No ${itemType.name.toLowerCase()} match the current filters.'
        : 'No ${itemType.name.toLowerCase()} found yet.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Icon(
            itemType.icon,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
