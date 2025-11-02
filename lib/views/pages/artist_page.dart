import 'package:flutter/material.dart';
import 'package:unimusic/components/lazy_image.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

class ArtistPage extends StatefulWidget {
  final Artist artist;

  const ArtistPage({super.key, required this.artist});

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showTitleInAppBar = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final showTitle = _scrollController.offset > 64;
    if (showTitle != _showTitleInAppBar) {
      setState(() {
        _showTitleInAppBar = showTitle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            title: AnimatedOpacity(
              opacity: _showTitleInAppBar ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Text(widget.artist.name),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.artist.artwork != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9999),
                      child: LazyImage(
                        artwork: widget.artist.artwork!,
                        icon: Icon(LibraryItemType.artists.icon),
                        width: 150,
                        height: 150,
                        size: ArtworkSize.medium,
                      ),
                    ),
                  if (widget.artist.artwork != null) const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: widget.artist.artwork != null ? 150 : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            widget.artist.name,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: Center(child: Text('TODO: More information here!'))),
        ],
      ),
    );
  }
}
