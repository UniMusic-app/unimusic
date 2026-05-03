import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class LibraryFilters {
  final String titleQuery;
  final String albumQuery;
  final String artistQuery;
  final Set<String> providerIds;

  const LibraryFilters({
    this.titleQuery = "",
    this.albumQuery = "",
    this.artistQuery = "",
    this.providerIds = const {},
  });

  bool get hasAnyFilters =>
      titleQuery.trim().isNotEmpty ||
      albumQuery.trim().isNotEmpty ||
      artistQuery.trim().isNotEmpty ||
      providerIds.isNotEmpty;

  int get textFilterCount => [
    titleQuery,
    albumQuery,
    artistQuery,
  ].where((value) => value.trim().isNotEmpty).length;
}

class LibraryFilterButton extends StatelessWidget {
  final LibraryFilters filters;
  final Set<MusicProvider> providers;
  final ValueChanged<LibraryFilters> onChanged;

  const LibraryFilterButton({
    super.key,
    required this.filters,
    required this.providers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final availableProviderIds = providers
        .map((provider) => provider.id)
        .toSet();
    final activeFilterCount =
        filters.textFilterCount +
        filters.providerIds.intersection(availableProviderIds).length;

    return IconButton(
      onPressed: () => _openFilters(context),
      tooltip: activeFilterCount > 0
          ? "Filter library ($activeFilterCount active)"
          : "Filter library",
      icon: Badge(
        isLabelVisible: activeFilterCount > 0,
        label: Text("$activeFilterCount"),
        child: const Icon(Symbols.filter_list_rounded),
      ),
    );
  }

  Future<void> _openFilters(BuildContext context) async {
    final nextFilters = await showModalBottomSheet<LibraryFilters>(
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      context: context,
      builder: (context) {
        return _LibraryFiltersSheet(
          initialFilters: filters,
          providers: providers,
        );
      },
    );

    if (nextFilters != null) {
      onChanged(nextFilters);
    }
  }
}

class _LibraryFiltersSheet extends StatefulWidget {
  final LibraryFilters initialFilters;
  final Set<MusicProvider> providers;

  const _LibraryFiltersSheet({
    required this.initialFilters,
    required this.providers,
  });

  @override
  State<_LibraryFiltersSheet> createState() => _LibraryFiltersSheetState();
}

class _LibraryFiltersSheetState extends State<_LibraryFiltersSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _albumController;
  late final TextEditingController _artistController;
  late Set<String> _selectedProviderIds;
  late final List<MusicProvider> _sortedProviders;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialFilters.titleQuery,
    );
    _albumController = TextEditingController(
      text: widget.initialFilters.albumQuery,
    );
    _artistController = TextEditingController(
      text: widget.initialFilters.artistQuery,
    );
    final availableProviderIds = widget.providers
        .map((provider) => provider.id)
        .toSet();
    _selectedProviderIds = widget.initialFilters.providerIds.intersection(
      availableProviderIds,
    );
    final providers = widget.providers.toList();
    providers.sort((a, b) => a.name.compareTo(b.name));
    _sortedProviders = providers;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _albumController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  LibraryFilters get _draftFilters {
    return LibraryFilters(
      titleQuery: _titleController.text.trim(),
      albumQuery: _albumController.text.trim(),
      artistQuery: _artistController.text.trim(),
      providerIds: _selectedProviderIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final draftFilters = _draftFilters;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Filter library",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: "Song",
                  prefixIcon: Icon(Symbols.music_note_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _albumController,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: "Album",
                  prefixIcon: Icon(Symbols.album_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _artistController,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: "Artist",
                  prefixIcon: Icon(Symbols.person_rounded),
                ),
              ),
              if (widget.providers.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  "Providers",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sortedProviders.map((provider) {
                    return FilterChip(
                      label: Text(provider.name),
                      selected: _selectedProviderIds.contains(provider.id),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedProviderIds.add(provider.id);
                          } else {
                            _selectedProviderIds.remove(provider.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  if (draftFilters.hasAnyFilters) ...[
                    TextButton.icon(
                      onPressed: _clearDraftFilters,
                      icon: const Icon(Symbols.filter_alt_off_rounded),
                      label: const Text("Clear filters"),
                    ),
                    const Spacer(),
                  ] else
                    const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, draftFilters),
                    child: const Text("Apply"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearDraftFilters() {
    setState(() {
      _titleController.clear();
      _albumController.clear();
      _artistController.clear();
      _selectedProviderIds.clear();
    });
  }
}
