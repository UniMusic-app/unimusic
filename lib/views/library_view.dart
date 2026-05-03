import "dart:async";

import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:unimusic/components/album_carousel_card.dart";
import "package:unimusic/components/empty_state_view.dart";
import "package:unimusic/components/library_filter_button.dart";
import "package:unimusic/components/tiles/music_item_tile.dart";
import "package:unimusic/services/provider_registry.dart";
import "package:unimusic/services/music_providers/music_provider.dart";
import "package:unimusic/utils/layout.dart";
import "package:unimusic/utils/string.dart";
import "package:provider/provider.dart";

class LibraryView extends StatefulWidget {
  final LibraryItemType? fixedItemType;

  const LibraryView({super.key, this.fixedItemType});

  @override
  State<LibraryView> createState() => LibraryViewState();
}

class LibraryViewState extends State<LibraryView>
    with SingleTickerProviderStateMixin {
  late final TabController tabController;
  late final ProviderRegistry _registry;
  final Map<LibraryItemType, Completer<void>> _refreshCompleters = {};

  List<LibraryItemType> get _visibleItemTypes => widget.fixedItemType == null
      ? LibraryItemType.values
      : [widget.fixedItemType!];

  LibraryItemType _itemTypeAt(int index) => _visibleItemTypes[index];

  LibrarySortBy sortBy = LibrarySortBy.name;
  LibrarySortOrder sortOrder = LibrarySortOrder.ascending;
  LibraryFilters filters = const LibraryFilters();
  Map<LibraryItemType, List<MusicItem>> libraryItems = {};

  /// Tracks whether the initial load has completed for each type.
  final Map<LibraryItemType, bool> _loadingDone = {};

  /// Active subscriptions so we can cancel on refresh or dispose.
  final Map<LibraryItemType, StreamSubscription<MusicItem>> _loadSubscriptions =
      {};

  /// Tracks the last-known provider instances so same-type services still reload.
  Set<MusicProvider> _knownProviders = {};

  final Map<LibrarySortBy, String> _sortLabels = {
    LibrarySortBy.name: "Name",
    LibrarySortBy.album: "Album",
    LibrarySortBy.artist: "Artist",
  };

  @override
  void initState() {
    super.initState();
    tabController = TabController(
      vsync: this,
      length: _visibleItemTypes.length,
    );
    _registry = context.read<ProviderRegistry>();
    _registry.addListener(_onRegistryChanged);
    _loadAllLibraryItems();
  }

  @override
  void dispose() {
    _registry.removeListener(_onRegistryChanged);
    tabController.dispose();
    for (final sub in _loadSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  /// Called on every MusicManager notification. Only reloads library when
  /// the set of provider instances has actually changed.
  void _onRegistryChanged() {
    final currentProviders = _registry.providers.toSet();
    if (!_setEquals(currentProviders, _knownProviders)) {
      _loadAllLibraryItems();
    }
  }

  static bool _setEquals<T>(Set<T> a, Set<T> b) {
    return a.length == b.length && a.containsAll(b);
  }

  void _loadAllLibraryItems() {
    _knownProviders = _registry.providers.toSet();
    for (final itemType in _visibleItemTypes) {
      _startLoading(itemType);
    }
  }

  void _startLoading(LibraryItemType itemType) {
    _loadSubscriptions[itemType]?.cancel();
    _loadingDone[itemType] = false;

    if (!mounted) return;
    setState(() {
      libraryItems[itemType] = [];
    });

    final stream = _registry.getLibraryItems(itemType: itemType);
    _loadSubscriptions[itemType] = stream.listen(
      (item) {
        if (!mounted) return;
        setState(() {
          libraryItems[itemType] ??= [];
          _insertSorted(itemType, item);
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _loadingDone[itemType] = true);
        _refreshCompleters[itemType]?.complete();
        _refreshCompleters.remove(itemType);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _loadingDone[itemType] = true);
        _refreshCompleters[itemType]?.complete();
        _refreshCompleters.remove(itemType);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableProviderIds = _registry.providers
        .map((provider) => provider.id)
        .toSet();

    final safeAreaPadding = MediaQuery.paddingOf(context);

    // When the sidebar is visible, it controls tab switching.
    final showTabBar =
        widget.fixedItemType == null &&
        MediaQuery.sizeOf(context).width < expandedBreakpoint;

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

            title: showTabBar
                ? const Text("Library")
                : widget.fixedItemType != null
                ? Text("${widget.fixedItemType!.name.capitalized}s")
                : AnimatedBuilder(
                    animation: tabController,
                    builder: (context, _) {
                      final type = _itemTypeAt(tabController.index);
                      return Text("${type.name.capitalized}s");
                    },
                  ),
            actions: [
              IconButton(
                onPressed: _changeSortOrder,
                icon: Icon(
                  sortOrder == LibrarySortOrder.ascending
                      ? Symbols.arrow_downward_rounded
                      : Symbols.arrow_upward_rounded,
                ),
                tooltip: "Sort Order",
              ),
              IconButton(
                onPressed: _changeSortBy,
                icon: const Icon(Symbols.sort_by_alpha_rounded),
                tooltip: "Sort By",
              ),
              LibraryFilterButton(
                filters: filters,
                providers: _registry.providers,
                onChanged: (nextFilters) {
                  setState(() {
                    filters = nextFilters;
                  });
                },
              ),
            ],

            bottom: showTabBar
                ? TabBar(
                    controller: tabController,
                    tabs: _visibleItemTypes.map((itemType) {
                      return Tab(text: itemType.name.capitalized);
                    }).toList(),
                  )
                : null,
          ),
        ];
      },

      body: TabBarView(
        controller: tabController,
        // Disable swipe when sidebar controls tabs.
        physics: showTabBar ? null : const NeverScrollableScrollPhysics(),
        children: _visibleItemTypes.map((itemType) {
          final filteredItems = _filteredItems(itemType, availableProviderIds);
          final hasActiveFilters =
              filters.textFilterCount > 0 ||
              filters.providerIds.intersection(availableProviderIds).isNotEmpty;
          final isStillLoading =
              filteredItems.isEmpty && !(_loadingDone[itemType] ?? false);

          if (isStillLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final showEmptyState = filteredItems.isEmpty;

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: _buildItemList(
              itemType: itemType,
              filteredItems: filteredItems,
              showEmptyState: showEmptyState,
              hasActiveFilters: hasActiveFilters,
              bottomPadding: safeAreaPadding.bottom + 8,
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final itemType = _itemTypeAt(tabController.index);
    _refreshCompleters[itemType] = Completer<void>();
    _startLoading(itemType);
    return _refreshCompleters[itemType]!.future;
  }

  Widget _buildItemList({
    required LibraryItemType itemType,
    required List<MusicItem> filteredItems,
    required bool showEmptyState,
    required bool hasActiveFilters,
    required double bottomPadding,
  }) {
    if (showEmptyState) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: EmptyStateView(
              icon: itemType.icon,
              iconColor: Theme.of(context).colorScheme.primary,
              message: hasActiveFilters
                  ? "No ${itemType.name.toLowerCase()} match the current filters."
                  : "No ${itemType.name.toLowerCase()} found yet.",
              messageStyle: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      );
    }

    // Albums use a grid on wider layouts.
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid =
            itemType == LibraryItemType.albums && constraints.maxWidth >= 500;

        if (useGrid) {
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: bottomPadding,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.765,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final item = filteredItems[index] as Album;
              return AlbumCarouselCard(item);
            },
          );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: 16, bottom: bottomPadding),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return MusicItemTile(item);
          },
        );
      },
    );
  }

  void _changeSortOrder() {
    setState(() {
      sortOrder = LibrarySortOrder.fromInt(sortOrder.toInt() * -1);
      for (final itemType in _visibleItemTypes) {
        _sortItems(itemType);
      }
    });
  }

  Future<void> _changeSortBy() async {
    final itemType = _itemTypeAt(tabController.index);
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
                Text("Sort by", style: Theme.of(context).textTheme.titleMedium),
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
        for (final type in _visibleItemTypes) {
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
    };
  }

  String _albumKey(MusicItem item) {
    return switch (item) {
      Song song => song.album ?? "",
      Album album => album.name,
      Artist artist => artist.name,
    };
  }

  String _artistKey(MusicItem item) {
    return switch (item) {
      Song song => song.artists.formatted,
      Album album => album.artists.formatted,
      Artist artist => artist.name,
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
            _matchesText(song.album ?? "", albumQuery) &&
            _matchesText(song.artists.formatted, artistQuery),
      Album album =>
        titleQuery.isEmpty &&
            _matchesText(album.name, albumQuery) &&
            _matchesText(album.artists.formatted, artistQuery),
      Artist artist =>
        titleQuery.isEmpty &&
            albumQuery.isEmpty &&
            _matchesText(artist.name, artistQuery),
    };
  }

  bool _matchesText(String source, String query) {
    if (query.isEmpty) return true;
    return source.toLowerCase().contains(query);
  }
}
