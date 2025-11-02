import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unimusic/services/music_manager.dart';

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
        const SnackBar(content: Text('Library cleanup complete!'), duration: Duration(seconds: 2)),
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
            title: const Text('Clean up library'),
            subtitle: const Text('Remove stale songs, albums, and artwork from the database.'),
            trailing: _isCleaning
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _cleanupGarbage, child: const Text('Clean')),
          ),
        ],
      ),
    );
  }
}
