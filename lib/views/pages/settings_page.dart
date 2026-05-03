import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:provider/provider.dart";
import "package:unimusic/services/provider_registry.dart";
import "package:unimusic/views/pages/services_page.dart";
import "package:unimusic/views/pages/theme_page.dart";

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: const SettingsContent(),
    );
  }
}

class SettingsContent extends StatefulWidget {
  const SettingsContent({super.key});

  @override
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent> {
  bool _isCleaning = false;

  Future<void> _cleanupGarbage() async {
    setState(() {
      _isCleaning = true;
    });

    final registry = context.read<ProviderRegistry>();
    for (final provider in registry.providers) {
      await provider.cleanupGarbage();
    }

    if (mounted) {
      setState(() {
        _isCleaning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Library cleanup complete!"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Symbols.music_note_rounded),
          title: const Text("Services"),
          subtitle: const Text("Manage connected music services"),
          trailing: const Icon(Symbols.chevron_right_rounded),
          onTap: () => ServicesPage.open(context),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Symbols.palette_rounded),
          title: const Text("Theme"),
          subtitle: const Text("Customize app appearance"),
          trailing: const Icon(Symbols.chevron_right_rounded),
          onTap: () => ThemePage.open(context),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Symbols.cleaning_services_rounded),
          title: const Text("Clean up library"),
          subtitle: const Text(
            "Remove stale songs, albums, and artworks from the database.",
          ),
          trailing: Stack(
            alignment: Alignment.center,
            children: [
              if (_isCleaning) ...const [
                ElevatedButton(
                  onPressed: null,
                  child: Text(
                    "Clean",
                    style: TextStyle(color: Colors.transparent),
                  ),
                ),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ] else
                ElevatedButton(
                  onPressed: _cleanupGarbage,
                  child: const Text("Clean"),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
