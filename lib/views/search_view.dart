import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unimusic/components/tiles/music_item_tile.dart';
import 'package:unimusic/components/tiles/search_hint_tile.dart';
import 'package:unimusic/services/music_manager.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      floatHeaderSlivers: true,
      headerSliverBuilder: (context, _) => [
        const SliverAppBar(
          pinned: true,
          floating: true,
          stretch: true,
          snap: true,
          scrolledUnderElevation: 0,
          toolbarHeight: kToolbarHeight + 16,
          title: ExcludeFocus(child: SearchBar()),
        ),
      ],
      body: const SizedBox.shrink(),
    );
  }
}

class SearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onSubmitted;

  const SearchBar({super.key, this.hint = 'Search', this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Hero(
      tag: 'search-hero',
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => _openSearchPage(context),
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.search),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      hint,
                      style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSearchPage(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, _, __) => SearchPage(hint: hint, onSubmitted: onSubmitted),
        opaque: false,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = 0.925;
          const end = 1.0;
          final tween = Tween(begin: begin, end: end);
          final scaleAnimation = animation.drive(tween);

          return ScaleTransition(
            scale: scaleAnimation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  final String hint;
  final ValueChanged<String>? onSubmitted;

  const SearchPage({super.key, this.hint = 'Search', this.onSubmitted});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final TabController _tabController;
  late final MusicManager _musicManager;
  Timer? _debounceTimer;

  String? _searchQuery;
  List<SearchHint> _searchHints = [];
  bool _isLoadingHints = false;

  static const _debounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_onSearchChanged);
    _tabController = TabController(length: LibraryItemType.values.length + 1, vsync: this);
    _musicManager = context.read<MusicManager>();
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();

    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchQuery = null;
        _searchHints = [];
        _isLoadingHints = false;
      });
      return;
    }

    if (_searchQuery != null) {
      setState(() => _searchQuery = null);
    }

    _debounceTimer = Timer(_debounceDuration, () => _fetchSearchHints(query));
  }

  Future<void> _fetchSearchHints(String query) async {
    setState(() => _isLoadingHints = true);

    final hints = <SearchHint>[];
    await for (final hint in _musicManager.getSearchHints(query: query)) {
      hints.add(hint);
    }

    if (mounted) {
      setState(() {
        _searchHints = hints;
        _isLoadingHints = false;
      });
    }
  }

  Future<void> _submitSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    _debounceTimer?.cancel();

    setState(() {
      _searchQuery = trimmedQuery;
      _searchHints = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(theme),
            if (_searchQuery != null) _buildTabBar(theme),
            if (_isLoadingHints) const LinearProgressIndicator(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Hero(
      tag: 'search-hero',
      child: Material(
        borderRadius: BorderRadius.circular(28),
        color: theme.colorScheme.surfaceContainerLow,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  autofocus: true,
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _submitSearch,
                  decoration: InputDecoration(hintText: widget.hint, border: InputBorder.none),
                ),
              ),
              if (_controller.text.isNotEmpty)
                IconButton(icon: const Icon(Icons.clear), onPressed: _controller.clear),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return TabBar(
      controller: _tabController,
      tabs: [
        const Tab(text: 'All'),
        ...LibraryItemType.values.map((type) => Tab(text: '${type.name}s')),
      ],
    );
  }

  Widget _buildContent() {
    if (_searchQuery != null) {
      return TabBarView(
        controller: _tabController,
        children: [
          SearchResultsTab(query: _searchQuery!, itemType: null),
          ...LibraryItemType.values.map(
            (type) => SearchResultsTab(query: _searchQuery!, itemType: type),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: _searchHints.length,
      itemBuilder: (context, index) {
        final hint = _searchHints[index];
        return SearchHintTile(
          searchHint: hint,
          onTap: () {
            _controller.text = hint.title;
            if (hint.type != null) {
              _tabController.animateTo(LibraryItemType.values.indexOf(hint.type!) + 1);
            }
            _submitSearch(hint.title);
          },
        );
      },
    );
  }
}

class SearchResultsTab extends StatefulWidget {
  final String query;
  final LibraryItemType? itemType;

  const SearchResultsTab({super.key, required this.query, required this.itemType});

  @override
  State<SearchResultsTab> createState() => _SearchResultsTabState();
}

class _SearchResultsTabState extends State<SearchResultsTab> with AutomaticKeepAliveClientMixin {
  late final MusicManager _musicManager;
  List<MusicItem> _results = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _musicManager = context.read<MusicManager>();
    _loadResults();
  }

  Future<void> _loadResults() async {
    if (_hasLoaded) return;

    setState(() {
      _isLoading = true;
      _hasLoaded = true;
    });

    final results = <MusicItem>[];
    await for (final item in _musicManager.getSearchResults(
      query: widget.query,
      itemType: widget.itemType,
    )) {
      results.add(item);
      if (mounted) {
        setState(() => _results = List.from(results));
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return MusicItemTile(item);
      },
    );
  }
}
