import 'package:flutter/material.dart';
import 'package:unimusic/views/pages/settings_page.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

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
            title: const Text("Home"),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ];
      },
      body: Column(),
    );
  }
}
