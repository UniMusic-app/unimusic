import "dart:io";

import "package:flutter/material.dart";

class AppSidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AppSidebarItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected
            ? theme.colorScheme.secondaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  color: selected
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                  fill: selected ? 1 : 0,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppSidebarSectionHeader extends StatelessWidget {
  final String label;

  const AppSidebarSectionHeader(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class AppSidebar extends StatelessWidget {
  /// Default width used to initialise the sidebar in the expanded layout.
  static const double defaultWidth = 240.0;

  static const double _macOSTitlebarHeight = 48.0;

  final List<Widget> items;
  final List<Widget> bottomItems;

  const AppSidebar({
    super.key,
    required this.items,
    this.bottomItems = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // On macOS the traffic lights are repositioned to align with the
    // toolbar area (see MainFlutterWindow.swift). The sidebar needs
    // matching top padding so items start below the traffic lights.
    // MediaQuery may report 0 for the safe-area top when the titlebar
    // is transparent+hidden, so enforce a minimum of the titlebar height.
    final systemTop = MediaQuery.paddingOf(context).top;
    final topPadding = Platform.isMacOS ? _macOSTitlebarHeight : systemTop;

    // The sidebar fills whatever width its parent imposes (controlled
    // externally via a SizedBox in the layout).
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          SizedBox(height: topPadding),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(child: Column(children: items)),
          ),
          ...bottomItems,
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
