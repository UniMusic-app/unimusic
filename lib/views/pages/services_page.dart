import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:provider/provider.dart";
import "package:unimusic/services/credentials_service.dart";
import "package:unimusic/services/provider_registry.dart";
import "package:unimusic/utils/platform.dart";
import "package:unimusic/views/pages/dialogs/deezer_auth_dialog.dart";
import "package:unimusic/views/pages/dialogs/jellyfin_auth_dialog.dart";
import "package:unimusic/views/pages/dialogs/local_directory_dialog.dart";
import "package:unimusic/views/pages/dialogs/service_tile.dart";

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ServicesPage()),
    );
  }

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
        final registry = context.read<ProviderRegistry>();
        await registry.addServiceFromCredentials(credentials);
        await _loadCredentials();
      }
    }
  }

  Future<void> _toggleDefaultLocalProvider(bool enabled) async {
    final credentials = LocalCredentials.defaultDirectories();
    if (enabled) {
      await CredentialsService.instance.saveCredentials(credentials);
      if (mounted) {
        final registry = context.read<ProviderRegistry>();
        await registry.addServiceFromCredentials(credentials);
      }
    } else {
      await CredentialsService.instance.removeCredentials(credentials);
      if (mounted) {
        final registry = context.read<ProviderRegistry>();
        registry.removeService(credentials);
      }
    }
    await _loadCredentials();
  }

  Future<void> _removeService(ServiceCredentials credentials) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Service"),
        content: Text(
          "Are you sure you want to remove ${_getDisplayName(credentials)}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CredentialsService.instance.removeCredentials(credentials);
      if (mounted) {
        final registry = context.read<ProviderRegistry>();
        registry.removeService(credentials);
        await _loadCredentials();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${_getDisplayName(credentials)} removed"),
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
                ? "Local Music"
                : c.customDirectory ?? "Custom Directory"),
      JellyfinCredentials c => c.displayName ?? "Jellyfin (${c.username})",
      DeezerCredentials c => c.displayName ?? "Deezer",
    };
  }

  IconData _getServiceIcon(ServiceType type) {
    return switch (type) {
      ServiceType.local => Symbols.folder_rounded,
      ServiceType.jellyfin => Symbols.dns_rounded,
      ServiceType.deezer => Symbols.music_note_rounded,
    };
  }

  Future<LocalCredentials?> _showLocalDirectoryDialog() async {
    return _showAnimatedDialog<LocalCredentials>(
      context: context,
      builder: (context) => const LocalDirectoryDialog(),
    );
  }

  Future<JellyfinCredentials?> _showJellyfinDialog({
    JellyfinCredentials? existing,
  }) async {
    return _showAnimatedDialog<JellyfinCredentials>(
      context: context,
      builder: (context) => JellyfinAuthDialog(existing: existing),
    );
  }

  Future<DeezerCredentials?> _showDeezerDialog({
    DeezerCredentials? existing,
  }) async {
    return _showAnimatedDialog<DeezerCredentials>(
      context: context,
      builder: (context) => DeezerAuthDialog(existing: existing),
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
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
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
      appBar: AppBar(title: const Text("Services")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Local Music section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Local Music",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // Default directories toggle (available on all platforms)
                SwitchListTile(
                  secondary: const Icon(Symbols.folder_rounded),
                  title: Text(
                    isMobile ? "Local Music" : "Default Music Folders",
                  ),
                  subtitle: Text(
                    isMobile
                        ? "Access music from your device"
                        : "Scan default Music directories",
                  ),
                  value: _hasDefaultLocalProvider,
                  onChanged: _toggleDefaultLocalProvider,
                ),
                // Custom directories (desktop only)
                if (isDesktop) ...[
                  // Show existing custom directories
                  ..._customLocalProviders.map(
                    (credentials) => ServiceTile(
                      credentials: credentials,
                      onRemove: () => _removeService(credentials),
                      getDisplayName: _getDisplayName,
                      getServiceIcon: _getServiceIcon,
                    ),
                  ),
                  // Add custom directory option
                  ListTile(
                    leading: const Icon(Symbols.create_new_folder_rounded),
                    title: const Text("Add Custom Directory"),
                    trailing: const Icon(Symbols.add_rounded),
                    onTap: () => _addService(ServiceType.local),
                  ),
                ],
                const Divider(),
                // Add streaming service section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Streaming Services",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...addableServiceTypes.map(
                  (type) => ListTile(
                    leading: Icon(_getServiceIcon(type)),
                    title: Text(type.displayName),
                    trailing: const Icon(Symbols.add_rounded),
                    onTap: () => _addService(type),
                  ),
                ),
                const Divider(),
                // Connected services section (non-local)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Connected Services",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (nonLocalCredentials.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "No streaming services connected.",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ...nonLocalCredentials.map(
                    (credentials) => ServiceTile(
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
