import "package:flutter/material.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:unimusic/services/credentials_service.dart";

class ServiceTile extends StatelessWidget {
  final ServiceCredentials credentials;
  final VoidCallback onRemove;
  final String Function(ServiceCredentials) getDisplayName;
  final IconData Function(ServiceType) getServiceIcon;

  const ServiceTile({
    super.key,
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
            ? "Default music directories"
            : c.customDirectory ?? "Custom directory",
      JellyfinCredentials c => c.serverUri,
      DeezerCredentials _ => "Connected via ARL",
    };

    return ListTile(
      leading: Icon(getServiceIcon(credentials.type)),
      title: Text(getDisplayName(credentials)),
      subtitle: Text(subtitle),
      trailing: IconButton(
        tooltip: "Remove",
        icon: const Icon(Symbols.delete_outline_rounded),
        onPressed: onRemove,
      ),
    );
  }
}
