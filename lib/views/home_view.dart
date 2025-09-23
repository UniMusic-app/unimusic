import 'package:flutter/material.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      floatHeaderSlivers: true,
      headerSliverBuilder: (BuildContext context, _) {
        return const [
          SliverAppBar(
            pinned: true,
            floating: true,
            stretch: true,
            snap: true,
            title: Text("Homer"),
          ),
        ];
      },
      body: Column(),
    );
  }
}
