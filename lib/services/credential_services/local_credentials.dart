part of '../credentials_service.dart';

class LocalCredentials extends ServiceCredentials {
  final bool useDefaultDirectories;
  final String? customDirectory;
  final String? displayName;

  const LocalCredentials({
    required this.useDefaultDirectories,
    this.customDirectory,
    this.displayName,
  }) : super(type: ServiceType.local);

  factory LocalCredentials.defaultDirectories() {
    return const LocalCredentials(useDefaultDirectories: true);
  }

  factory LocalCredentials.customDirectory({
    required String directory,
    String? displayName,
  }) {
    return LocalCredentials(
      useDefaultDirectories: false,
      customDirectory: directory,
      displayName: displayName,
    );
  }

  @override
  int get hashCode => Object.hash(type, useDefaultDirectories, customDirectory);

  @override
  bool operator ==(Object other) =>
      other is LocalCredentials &&
      other.useDefaultDirectories == useDefaultDirectories &&
      other.customDirectory == customDirectory;

  @override
  Map<String, dynamic> toJson() => {
    'type': type.id,
    'useDefaultDirectories': useDefaultDirectories,
    'customDirectory': customDirectory,
    'displayName': displayName,
  };

  factory LocalCredentials.fromJson(Map<String, dynamic> json) {
    return LocalCredentials(
      useDefaultDirectories: json['useDefaultDirectories'] as bool? ?? true,
      customDirectory: json['customDirectory'] as String?,
      displayName: json['displayName'] as String?,
    );
  }
}
