import 'package:flutter/material.dart';
import 'package:unimusic/components/lazy_image.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';

class SearchHintTile extends StatelessWidget {
  final SearchHint searchHint;
  final void Function()? onTap;

  const SearchHintTile({required this.searchHint, this.onTap, super.key})
    : super();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,

      minTileHeight: 12,
      dense: true,

      leading: ClipRRect(
        borderRadius: BorderRadius.circular(searchHint.type?.borderRadius ?? 0),
        child: LazyImage(
          artwork: searchHint.artwork,
          icon: Icon(searchHint.type?.icon ?? Icons.search),
          width: 48,
          size: ArtworkSize.small,
          animationDuration: Duration(milliseconds: 150),
        ),
      ),

      title: Text(
        searchHint.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        searchHint.type?.name ?? "",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
