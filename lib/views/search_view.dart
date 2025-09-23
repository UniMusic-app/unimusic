import 'package:flutter/material.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
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

            toolbarHeight: kToolbarHeight + 16,
            title: Text("Search"),
          ),
        ];
      },
      body: Column(),
    );
  }
}
