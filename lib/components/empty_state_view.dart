import "package:flutter/material.dart";

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String message;
  final double iconSize;
  final Color? iconColor;
  final TextStyle? messageStyle;
  final Widget? action;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.message,
    this.iconSize = 40,
    this.iconColor,
    this.messageStyle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: messageStyle),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    );
  }
}
