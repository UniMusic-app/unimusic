import 'dart:io';

import 'package:flutter/material.dart';

abstract class AdaptiveMenuItem {}

class MenuHeader extends AdaptiveMenuItem {
  final Widget child;
  MenuHeader({required this.child});
}

class MenuAction extends AdaptiveMenuItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  MenuAction({required this.title, required this.icon, required this.onTap});
}

class MenuDivider extends AdaptiveMenuItem {}

class AdaptiveContextMenu extends StatelessWidget {
  final Widget child;
  final List<AdaptiveMenuItem> items;

  const AdaptiveContextMenu({
    super.key,
    required this.child,
    required this.items,
  });

  bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: isDesktop
          ? (details) => _showDesktopMenu(context, details.globalPosition)
          : null,
      onLongPress: !isDesktop ? () => _showMobileBottomSheet(context) : null,
      child: child,
    );
  }

  void _showMobileBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 12, bottom: 24),
                children: items
                    .map((item) => _buildMobileItem(context, item))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileItem(BuildContext context, AdaptiveMenuItem item) {
    if (item is MenuHeader) {
      return Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 8),
        child: item.child,
      );
    } else if (item is MenuDivider) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(),
      );
    } else if (item is MenuAction) {
      return ListTile(
        dense: true,
        leading: Icon(item.icon),
        title: Text(item.title),
        onTap: () {
          Navigator.pop(context);
          item.onTap();
        },
      );
    }

    throw Exception("Unsupported AdaptiveMenuItem on Mobile: $item");
  }

  void _showDesktopMenu(BuildContext context, Offset globalPosition) async {
    final double left = globalPosition.dx;
    final double top = globalPosition.dy;

    await showMenu(
      context: context,
      useRootNavigator: true,
      elevation: 3,
      constraints: BoxConstraints.loose(Size(double.infinity, double.infinity)),
      popUpAnimationStyle: const AnimationStyle(
        curve: Curves.easeIn,
        duration: Duration(milliseconds: 150),
        reverseCurve: Curves.easeOut,
        reverseDuration: Duration(milliseconds: 150),
      ),
      position: RelativeRect.fromLTRB(left, top, left, top),
      items: items.map((item) => _buildDesktopItem(context, item)).toList(),
    );
  }

  PopupMenuEntry _buildDesktopItem(
    BuildContext context,
    AdaptiveMenuItem item,
  ) {
    if (item is MenuHeader) {
      return PopupMenuItem(
        enabled: false,
        height: kMinInteractiveDimension,
        labelTextStyle: WidgetStateProperty.all(
          Theme.of(context).textTheme.bodyMedium,
        ),
        child: item.child,
      );
    } else if (item is MenuDivider) {
      return const PopupMenuDivider();
    } else if (item is MenuAction) {
      return PopupMenuItem(
        onTap: item.onTap,
        child: Row(
          spacing: 12,
          children: [
            Icon(item.icon, color: Theme.of(context).colorScheme.onSurface),
            Text(item.title),
          ],
        ),
      );
    }
    throw Exception("Unsupported AdaptiveMenuItem on Desktop: $item");
  }
}
