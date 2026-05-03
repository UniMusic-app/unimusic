import "package:flex_color_picker/flex_color_picker.dart";
import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:provider/provider.dart";
import "package:unimusic/services/theme_service.dart";

const _presetColors = <({String label, Color color})>[
  (label: "Red", color: Colors.red),
  (label: "Orange", color: Colors.orange),
  (label: "Amber", color: Colors.amber),
  (label: "Green", color: Colors.green),
  (label: "Teal", color: Colors.teal),
  (label: "Cyan", color: Colors.cyan),
  (label: "Blue", color: Colors.blue),
  (label: "Indigo", color: Colors.indigo),
  (label: "Purple", color: Colors.purple),
  (label: "Pink", color: Colors.pink),
];

class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ThemePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Theme")),
      body: const _ThemeContent(),
    );
  }
}

class _ThemeContent extends StatelessWidget {
  const _ThemeContent();

  Future<void> _openCustomPicker(BuildContext context) async {
    // Capture these before the async gap.
    final themeService = context.read<ThemeService>();
    final scheme = Theme.of(context).colorScheme;
    final startColor = themeService.customColor ?? scheme.primary;

    Color pickedColor = startColor;
    final confirmed =
        await ColorPicker(
          color: startColor,
          onColorChanged: (color) => pickedColor = color,
          enableTonalPalette: true,
          showColorCode: true,
          colorCodeHasColor: true,
          title: Text(
            "Custom Color",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          pickersEnabled: const {
            ColorPickerType.both: false,
            ColorPickerType.primary: false,
            ColorPickerType.accent: false,
            ColorPickerType.bw: false,
            ColorPickerType.custom: false,
            ColorPickerType.wheel: true,
          },
        ).showPickerDialog(
          context,
          constraints: const BoxConstraints(
            minHeight: 460,
            minWidth: 300,
            maxWidth: 320,
          ),
        );

    if (confirmed) {
      await themeService.setCustomColor(pickedColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final themeService = context.watch<ThemeService>();

    final isAutoSelected = themeService.seedColor == null;
    final isCustomSelected = themeService.isCustomMode;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text("App Color", style: theme.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Text(
            "Choose a preset, pick any custom color, or follow your device's system color.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              _ColorSwatch(
                label: "Auto",
                color: null,
                selected: isAutoSelected,
                onTap: themeService.setAuto,
              ),
              _ColorSwatch(
                label: "Custom",
                color: themeService.customColor ?? scheme.secondaryContainer,
                selected: isCustomSelected,
                child: themeService.customColor == null
                    ? Icon(
                        Symbols.palette_rounded,
                        color: scheme.onSecondaryContainer,
                        size: 20,
                      )
                    : null,
                onTap: () => _openCustomPicker(context),
              ),
              for (final preset in _presetColors)
                _ColorSwatch(
                  label: preset.label,
                  color: preset.color,
                  selected:
                      !isCustomSelected &&
                      themeService.seedColor == preset.color,
                  onTap: () => themeService.setPresetColor(preset.color),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final String label;

  /// Solid circle color. Pass null to render a sweep gradient (Auto).
  final Color? color;

  final bool selected;

  /// Widget shown inside the circle when not selected (e.g. palette icon for
  /// the Custom swatch before a color has been picked).
  final Widget? child;

  final VoidCallback onTap;

  const _ColorSwatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isGradient = color == null;
    final ringColor = color ?? scheme.primary;

    // Ensure the check icon is legible against whatever the circle shows.
    final checkColor = isGradient
        ? Colors.white
        : (color!.computeLuminance() > 0.5 ? Colors.black87 : Colors.white);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (selected)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ringColor, width: 2.5),
                      ),
                    ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isGradient ? null : color,
                      gradient: isGradient
                          ? SweepGradient(
                              colors: [
                                scheme.primary,
                                scheme.secondary,
                                scheme.tertiary,
                                scheme.primary,
                              ],
                            )
                          : null,
                    ),
                    child: selected
                        ? Icon(
                            Symbols.check_rounded,
                            color: checkColor,
                            size: 20,
                          )
                        : child,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
