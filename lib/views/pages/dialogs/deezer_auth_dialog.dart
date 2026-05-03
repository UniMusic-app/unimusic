import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:unimusic/services/credentials_service.dart";

/// Dialog for Deezer authentication.
class DeezerAuthDialog extends StatefulWidget {
  final DeezerCredentials? existing;

  const DeezerAuthDialog({super.key, this.existing});

  @override
  State<DeezerAuthDialog> createState() => _DeezerAuthDialogState();
}

class _DeezerAuthDialogState extends State<DeezerAuthDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _arlController;
  late final TextEditingController _displayNameController;
  bool _isLoading = false;
  bool _obscureArl = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _arlController = TextEditingController(text: widget.existing?.arl);
    _displayNameController = TextEditingController(
      text: widget.existing?.displayName,
    );
  }

  @override
  void dispose() {
    _arlController.dispose();
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
      final credentials = DeezerCredentials(
        arl: _arlController.text.trim(),
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
        widget.existing == null ? "Add Deezer Account" : "Edit Deezer Account",
      ),
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
                  "To connect your Deezer account, you need to provide your ARL cookie. "
                  "This can be found in your browser's developer tools after logging into Deezer.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _arlController,
                  decoration: InputDecoration(
                    labelText: "ARL Cookie",
                    prefixIcon: const Icon(Symbols.cookie_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureArl
                            ? Symbols.visibility_rounded
                            : Symbols.visibility_off_rounded,
                      ),
                      onPressed: () =>
                          setState(() => _obscureArl = !_obscureArl),
                    ),
                  ),
                  obscureText: _obscureArl,
                  maxLines: 1,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter your ARL cookie";
                    }
                    if (value.trim().length < 100) {
                      return "ARL cookie seems too short";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: "Display Name (optional)",
                    hintText: "My Deezer Account",
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
