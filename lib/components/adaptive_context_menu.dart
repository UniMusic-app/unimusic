import "package:flutter/material.dart";
import "package:unimusic/utils/platform.dart";

sealed class AdaptiveMenuItem {}

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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      onLongPressHint: !isDesktop ? "Show options" : null,
      child: GestureDetector(
        onSecondaryTapDown: isDesktop
            ? (details) => _showDesktopMenu(context, details.globalPosition)
            : null,
        onLongPress: !isDesktop ? () => _showMobileBottomSheet(context) : null,
        child: child,
      ),
    );
  }

  void _showMobileBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 24),
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

  Widget _buildMobileItem(BuildContext context, AdaptiveMenuItem item) =>
      switch (item) {
        MenuHeader(:final child) => Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: child,
        ),
        MenuDivider() => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(),
        ),
        MenuAction(:final icon, :final title, :final onTap) => ListTile(
          dense: true,
          leading: Icon(icon),
          title: Text(title),
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
        ),
      };

  void _showDesktopMenu(BuildContext context, Offset globalPosition) async {
    final double left = globalPosition.dx;
    final double top = globalPosition.dy;

    await showMenu(
      context: context,
      useRootNavigator: true,
      elevation: 3,
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

  PopupMenuEntry<void> _buildDesktopItem(
    BuildContext context,
    AdaptiveMenuItem item,
  ) => switch (item) {
    MenuHeader(:final child) => PopupMenuItem(
      enabled: false,
      height: kMinInteractiveDimension,
      labelTextStyle: WidgetStateProperty.all(
        Theme.of(context).textTheme.bodyMedium,
      ),
      child: child,
    ),
    MenuDivider() => const PopupMenuDivider(),
    MenuAction(:final icon, :final title, :final onTap) => PopupMenuItem(
      onTap: onTap,
      child: Row(
        spacing: 12,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface),
          Text(title),
        ],
      ),
    ),
  };
}
