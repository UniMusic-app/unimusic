import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:unimusic/utils/layout.dart";
import "package:unimusic/views/pages/settings_page.dart";

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    // On wider layouts the sidebar provides settings access.
    final isCompact = MediaQuery.sizeOf(context).width < expandedBreakpoint;

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
              if (isCompact)
                IconButton(
                  tooltip: "Settings",
                  icon: const Icon(Symbols.settings_rounded),
                  onPressed: () => SettingsPage.open(context),
                ),
            ],
          ),
        ];
      },
      body: const Column(),
    );
  }
}
