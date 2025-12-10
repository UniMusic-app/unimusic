part of '../credentials_service.dart';

class JellyfinCredentials extends ServiceCredentials {
  final String serverUri;
  final String username;
  final String password;
  final String? displayName;

  const JellyfinCredentials({
    required this.serverUri,
    required this.username,
    required this.password,
    this.displayName,
  }) : super(type: ServiceType.jellyfin);

  @override
  int get hashCode => Object.hash(type, serverUri, username);

  @override
  bool operator ==(Object other) =>
      other is JellyfinCredentials &&
      other.serverUri == serverUri &&
      other.username == username;

  @override
  Map<String, dynamic> toJson() => {
    'type': type.id,
    'serverUri': serverUri,
    'username': username,
    'password': password,
    'displayName': displayName,
  };

  factory JellyfinCredentials.fromJson(Map<String, dynamic> json) {
    return JellyfinCredentials(
      serverUri: json['serverUri'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      displayName: json['displayName'] as String?,
    );
  }
}
