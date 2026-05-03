import "dart:io";

import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:unimusic/services/credentials_service.dart";

/// Dialog for adding a custom local music directory (desktop only).
class LocalDirectoryDialog extends StatefulWidget {
  const LocalDirectoryDialog({super.key});

  @override
  State<LocalDirectoryDialog> createState() => _LocalDirectoryDialogState();
}

class _LocalDirectoryDialogState extends State<LocalDirectoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _directoryController = TextEditingController();
  final _displayNameController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _directoryController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final directory = _directoryController.text.trim();

    if (!Directory(directory).existsSync()) {
      setState(() {
        _errorMessage = "Directory does not exist";
      });
      return;
    }

    final credentials = LocalCredentials.customDirectory(
      directory: directory,
      displayName: _displayNameController.text.trim().isEmpty
          ? null
          : _displayNameController.text.trim(),
    );

    Navigator.pop(context, credentials);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Music Directory"),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Enter the path to a folder containing your music files.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _directoryController,
                  decoration: const InputDecoration(
                    labelText: "Directory Path",
                    hintText: "/Users/username/Music",
                    prefixIcon: Icon(Symbols.folder_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter a directory path";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: "Display Name (optional)",
                    hintText: "My Music Collection",
                    prefixIcon: Icon(Symbols.label_rounded),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(onPressed: _submit, child: const Text("Add")),
      ],
    );
  }
}
