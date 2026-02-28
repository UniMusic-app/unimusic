import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unimusic/services/music_manager.dart';
import 'package:unimusic/views/pages/services_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isCleaning = false;

  Future<void> _cleanupGarbage() async {
    setState(() {
      _isCleaning = true;
    });

    final musicManager = context.read<MusicManager>();
    for (final provider in musicManager.providers) {
      await provider.cleanupGarbage();
    }

    if (mounted) {
      setState(() {
        _isCleaning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Library cleanup complete!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.music_note_outlined),
            title: const Text('Services'),
            subtitle: const Text('Manage connected music services'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ServicesPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clean up library'),
            subtitle: const Text(
              'Remove stale songs, albums, and artworks from the database.',
            ),
            trailing: Stack(
              alignment: Alignment.center,
              children: [
                if (_isCleaning) ...const [
                  ElevatedButton(
                    onPressed: null,
                    child: Text(
                      'Clean',
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
                    child: const Text('Clean'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
