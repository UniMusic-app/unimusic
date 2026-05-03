import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:unimusic/services/credentials_service.dart";

/// Dialog for Jellyfin authentication.
class JellyfinAuthDialog extends StatefulWidget {
  final JellyfinCredentials? existing;

  const JellyfinAuthDialog({super.key, this.existing});

  @override
  State<JellyfinAuthDialog> createState() => _JellyfinAuthDialogState();
}

class _JellyfinAuthDialogState extends State<JellyfinAuthDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _serverUriController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _displayNameController;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _serverUriController = TextEditingController(
      text: widget.existing?.serverUri,
    );
    _usernameController = TextEditingController(
      text: widget.existing?.username,
    );
    _passwordController = TextEditingController(
      text: widget.existing?.password,
    );
    _displayNameController = TextEditingController(
      text: widget.existing?.displayName,
    );
  }

  @override
  void dispose() {
    _serverUriController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Test the connection before saving
      final serverUri = Uri.tryParse(_serverUriController.text.trim());
      if (serverUri == null) {
        throw Exception("Invalid server URL");
      }

      // Create credentials
      final credentials = JellyfinCredentials(
        serverUri: _serverUriController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim().isEmpty
            ? null
            : _displayNameController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, credentials);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? "Add Jellyfin Server"
            : "Edit Jellyfin Server",
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _serverUriController,
                  decoration: const InputDecoration(
                    labelText: "Server URL",
                    hintText: "https://jellyfin.example.com",
                    prefixIcon: Icon(Symbols.dns_rounded),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter a server URL";
                    }
                    final uri = Uri.tryParse(value.trim());
                    if (uri == null || !uri.hasScheme) {
                      return "Please enter a valid URL";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: "Username",
                    prefixIcon: Icon(Symbols.person_rounded),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter a username";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Symbols.lock_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Symbols.visibility_rounded
                            : Symbols.visibility_off_rounded,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: "Display Name (optional)",
                    hintText: "My Jellyfin Server",
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
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.existing == null ? "Add" : "Save"),
        ),
      ],
    );
  }
}
