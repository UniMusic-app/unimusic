import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unimusic/services/credentials_service.dart';
import 'package:unimusic/services/music_manager.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  List<ServiceCredentials> _credentials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    setState(() => _isLoading = true);
    final credentials = await CredentialsService.instance.getCredentials();
    setState(() {
      _credentials = credentials;
      _isLoading = false;
    });
  }

  bool get _hasDefaultLocalProvider =>
      _credentials.any((c) => c is LocalCredentials && c.useDefaultDirectories);

  List<LocalCredentials> get _customLocalProviders => _credentials
      .whereType<LocalCredentials>()
      .where((c) => !c.useDefaultDirectories)
      .toList();

  Future<void> _addService(ServiceType type) async {
    final credentials = await switch (type) {
      ServiceType.local => _showLocalDirectoryDialog(),
      ServiceType.jellyfin => _showJellyfinDialog(),
      ServiceType.deezer => _showDeezerDialog(),
    };

    if (credentials != null) {
      await CredentialsService.instance.saveCredentials(credentials);
      if (mounted) {
        final musicManager = context.read<MusicManager>();
        await musicManager.addServiceFromCredentials(credentials);
        await _loadCredentials();
      }
    }
  }

  Future<void> _toggleDefaultLocalProvider(bool enabled) async {
    final credentials = LocalCredentials.defaultDirectories();
    if (enabled) {
      await CredentialsService.instance.saveCredentials(credentials);
      if (mounted) {
        final musicManager = context.read<MusicManager>();
        await musicManager.addServiceFromCredentials(credentials);
      }
    } else {
      await CredentialsService.instance.removeCredentials(credentials);
      if (mounted) {
        final musicManager = context.read<MusicManager>();
        musicManager.removeService(credentials);
      }
    }
    await _loadCredentials();
  }

  Future<void> _removeService(ServiceCredentials credentials) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Service'),
        content: Text(
          'Are you sure you want to remove ${_getDisplayName(credentials)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CredentialsService.instance.removeCredentials(credentials);
      if (mounted) {
        final musicManager = context.read<MusicManager>();
        musicManager.removeService(credentials);
        await _loadCredentials();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_getDisplayName(credentials)} removed'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  String _getDisplayName(ServiceCredentials credentials) {
    return switch (credentials) {
      LocalCredentials c =>
        c.displayName ??
            (c.useDefaultDirectories
                ? 'Local Music'
                : c.customDirectory ?? 'Custom Directory'),
      JellyfinCredentials c => c.displayName ?? 'Jellyfin (${c.username})',
      DeezerCredentials c => c.displayName ?? 'Deezer',
    };
  }

  IconData _getServiceIcon(ServiceType type) {
    return switch (type) {
      ServiceType.local => Icons.folder_outlined,
      ServiceType.jellyfin => Icons.dns_outlined,
      ServiceType.deezer => Icons.music_note_outlined,
    };
  }

  Future<LocalCredentials?> _showLocalDirectoryDialog() async {
    return _showAnimatedDialog<LocalCredentials>(
      context: context,
      builder: (context) => const _LocalDirectoryDialog(),
    );
  }

  Future<JellyfinCredentials?> _showJellyfinDialog({
    JellyfinCredentials? existing,
  }) async {
    return _showAnimatedDialog<JellyfinCredentials>(
      context: context,
      builder: (context) => _JellyfinAuthDialog(existing: existing),
    );
  }

  Future<DeezerCredentials?> _showDeezerDialog({
    DeezerCredentials? existing,
  }) async {
    return _showAnimatedDialog<DeezerCredentials>(
      context: context,
      builder: (context) => _DeezerAuthDialog(existing: existing),
    );
  }

  Future<T?> _showAnimatedDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(opacity: curvedAnimation, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter out local service type from "Add Service" section on mobile
    // since mobile only has the toggle for default directories
    final addableServiceTypes = ServiceType.values
        .where((type) => type != ServiceType.local)
        .toList();

    // Get non-local credentials for the "Connected Services" section
    final nonLocalCredentials = _credentials
        .where((c) => c is! LocalCredentials)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Local Music section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Local Music',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // Default directories toggle (available on all platforms)
                SwitchListTile(
                  secondary: const Icon(Icons.folder_outlined),
                  title: Text(
                    isMobile ? 'Local Music' : 'Default Music Folders',
                  ),
                  subtitle: Text(
                    isMobile
                        ? 'Access music from your device'
                        : 'Scan default Music directories',
                  ),
                  value: _hasDefaultLocalProvider,
                  onChanged: _toggleDefaultLocalProvider,
                ),
                // Custom directories (desktop only)
                if (isDesktop) ...[
                  // Show existing custom directories
                  ..._customLocalProviders.map(
                    (credentials) => _ServiceTile(
                      credentials: credentials,
                      onRemove: () => _removeService(credentials),
                      getDisplayName: _getDisplayName,
                      getServiceIcon: _getServiceIcon,
                    ),
                  ),
                  // Add custom directory option
                  ListTile(
                    leading: const Icon(Icons.create_new_folder_outlined),
                    title: const Text('Add Custom Directory'),
                    trailing: const Icon(Icons.add),
                    onTap: () => _addService(ServiceType.local),
                  ),
                ],
                const Divider(),
                // Add streaming service section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Streaming Services',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...addableServiceTypes.map(
                  (type) => ListTile(
                    leading: Icon(_getServiceIcon(type)),
                    title: Text(type.displayName),
                    trailing: const Icon(Icons.add),
                    onTap: () => _addService(type),
                  ),
                ),
                const Divider(),
                // Connected services section (non-local)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Connected Services',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (nonLocalCredentials.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'No streaming services connected.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ...nonLocalCredentials.map(
                    (credentials) => _ServiceTile(
                      credentials: credentials,
                      onRemove: () => _removeService(credentials),
                      getDisplayName: _getDisplayName,
                      getServiceIcon: _getServiceIcon,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final ServiceCredentials credentials;
  final VoidCallback onRemove;
  final String Function(ServiceCredentials) getDisplayName;
  final IconData Function(ServiceType) getServiceIcon;

  const _ServiceTile({
    required this.credentials,
    required this.onRemove,
    required this.getDisplayName,
    required this.getServiceIcon,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (credentials) {
      LocalCredentials c =>
        c.useDefaultDirectories
            ? 'Default music directories'
            : c.customDirectory ?? 'Custom directory',
      JellyfinCredentials c => c.serverUri,
      DeezerCredentials _ => 'Connected via ARL',
    };

    return ListTile(
      leading: Icon(getServiceIcon(credentials.type)),
      title: Text(getDisplayName(credentials)),
      subtitle: Text(subtitle),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onRemove,
      ),
    );
  }
}

/// Dialog for Jellyfin authentication.
class _JellyfinAuthDialog extends StatefulWidget {
  final JellyfinCredentials? existing;

  const _JellyfinAuthDialog({this.existing});

  @override
  State<_JellyfinAuthDialog> createState() => _JellyfinAuthDialogState();
}

class _JellyfinAuthDialogState extends State<_JellyfinAuthDialog> {
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
        throw Exception('Invalid server URL');
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
            ? 'Add Jellyfin Server'
            : 'Edit Jellyfin Server',
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
                    labelText: 'Server URL',
                    hintText: 'https://jellyfin.example.com',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a server URL';
                    }
                    final uri = Uri.tryParse(value.trim());
                    if (uri == null || !uri.hasScheme) {
                      return 'Please enter a valid URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
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
                    labelText: 'Display Name (optional)',
                    hintText: 'My Jellyfin Server',
                    prefixIcon: Icon(Icons.label_outline),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

/// Dialog for Deezer authentication.
class _DeezerAuthDialog extends StatefulWidget {
  final DeezerCredentials? existing;

  const _DeezerAuthDialog({this.existing});

  @override
  State<_DeezerAuthDialog> createState() => _DeezerAuthDialogState();
}

class _DeezerAuthDialogState extends State<_DeezerAuthDialog> {
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
        widget.existing == null ? 'Add Deezer Account' : 'Edit Deezer Account',
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
                  'To connect your Deezer account, you need to provide your ARL cookie. '
                  'This can be found in your browser\'s developer tools after logging into Deezer.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _arlController,
                  decoration: InputDecoration(
                    labelText: 'ARL Cookie',
                    prefixIcon: const Icon(Icons.cookie_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureArl ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscureArl = !_obscureArl),
                    ),
                  ),
                  obscureText: _obscureArl,
                  maxLines: 1,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your ARL cookie';
                    }
                    if (value.trim().length < 100) {
                      return 'ARL cookie seems too short';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name (optional)',
                    hintText: 'My Deezer Account',
                    prefixIcon: Icon(Icons.label_outline),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

/// Dialog for adding a custom local music directory (desktop only).
class _LocalDirectoryDialog extends StatefulWidget {
  const _LocalDirectoryDialog();

  @override
  State<_LocalDirectoryDialog> createState() => _LocalDirectoryDialogState();
}

class _LocalDirectoryDialogState extends State<_LocalDirectoryDialog> {
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
        _errorMessage = 'Directory does not exist';
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
      title: const Text('Add Music Directory'),
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
                  'Enter the path to a folder containing your music files.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _directoryController,
                  decoration: const InputDecoration(
                    labelText: 'Directory Path',
                    hintText: '/Users/username/Music',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a directory path';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name (optional)',
                    hintText: 'My Music Collection',
                    prefixIcon: Icon(Icons.label_outline),
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
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
