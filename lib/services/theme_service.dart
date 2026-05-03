import "dart:convert";
import "dart:io";

import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart";

class ThemeService extends ChangeNotifier {
  static const _prefsFileName = "theme_prefs.json";

  Color? _seedColor;
  Color? _customColor;
  bool _isCustomMode = false;

  Color? get seedColor => _seedColor;
  Color? get customColor => _customColor;
  bool get isCustomMode => _isCustomMode;

  ThemeService._();

  static Future<ThemeService> load() async {
    final service = ThemeService._();
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File("${dir.path}/$_prefsFileName");
      if (await file.exists()) {
        final data =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final seedValue = data["seedColor"] as int?;
        final customValue = data["customColor"] as int?;
        if (seedValue != null) service._seedColor = Color(seedValue);
        if (customValue != null) service._customColor = Color(customValue);
        service._isCustomMode = data["useCustom"] as bool? ?? false;
      }
    } catch (_) {}
    return service;
  }

  Future<void> setAuto() async {
    _seedColor = null;
    _isCustomMode = false;
    notifyListeners();
    await _save();
  }

  Future<void> setPresetColor(Color color) async {
    _seedColor = color;
    _isCustomMode = false;
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(Color color) async {
    _seedColor = color;
    _customColor = color;
    _isCustomMode = true;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File("${dir.path}/$_prefsFileName");
      await file.writeAsString(
        jsonEncode({
          "seedColor": _seedColor?.toARGB32(),
          "customColor": _customColor?.toARGB32(),
          "useCustom": _isCustomMode,
        }),
      );
    } catch (_) {}
  }
}
