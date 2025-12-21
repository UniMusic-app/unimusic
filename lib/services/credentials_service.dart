import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

part 'credential_services/local_credentials.dart';
part 'credential_services/jellyfin_credentials.dart';
part 'credential_services/deezer_credentials.dart';

enum ServiceType {
  local('Local Music', 'local'),
  jellyfin('Jellyfin', 'jellyfin'),
  deezer('Deezer', 'deezer');

  final String displayName;
  final String id;
  const ServiceType(this.displayName, this.id);

  static ServiceType? fromId(String id) {
    return ServiceType.values.where((s) => s.id == id).firstOrNull;
  }
}

bool get isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

bool get isMobile => Platform.isAndroid || Platform.isIOS;

sealed class ServiceCredentials {
  final ServiceType type;

  const ServiceCredentials({required this.type});

  Map<String, dynamic> toJson();

  static ServiceCredentials fromJson(Map<String, dynamic> json) {
    final type = ServiceType.fromId(json['type'] as String);
    return switch (type) {
      ServiceType.local => LocalCredentials.fromJson(json),
      ServiceType.jellyfin => JellyfinCredentials.fromJson(json),
      ServiceType.deezer => DeezerCredentials.fromJson(json),
      null => throw Exception('Unknown service type: ${json['type']}'),
    };
  }
}

class CredentialsService {
  static const _storageKey = 'unimusic_service_credentials';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(),
    lOptions: LinuxOptions(),
    wOptions: WindowsOptions(),
  );

  CredentialsService._();
  static final instance = CredentialsService._();

  List<ServiceCredentials>? _cachedCredentials;

  Future<List<ServiceCredentials>> getCredentials() async {
    if (_cachedCredentials != null) {
      return _cachedCredentials!;
    }

    final jsonString = await _storage.read(key: _storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      _cachedCredentials = [];
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      _cachedCredentials = jsonList
          .map(
            (item) => ServiceCredentials.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      return _cachedCredentials!;
    } catch (e) {
      _cachedCredentials = [];
      return [];
    }
  }

  Future<void> saveCredentials(ServiceCredentials credentials) async {
    final allCredentials = await getCredentials();

    allCredentials.remove(credentials);
    allCredentials.add(credentials);

    await _persistCredentials(allCredentials);
  }

  Future<void> removeCredentials(ServiceCredentials credentials) async {
    final allCredentials = await getCredentials();
    allCredentials.remove(credentials);
    await _persistCredentials(allCredentials);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _storageKey);
    _cachedCredentials = [];
  }

  Future<List<ServiceCredentials>> getCredentialsByType(
    ServiceType type,
  ) async {
    final allCredentials = await getCredentials();
    return allCredentials.where((c) => c.type == type).toList();
  }

  Future<void> _persistCredentials(List<ServiceCredentials> credentials) async {
    final jsonList = credentials.map((c) => c.toJson()).toList();
    await _storage.write(key: _storageKey, value: json.encode(jsonList));
    _cachedCredentials = credentials;
  }
}
