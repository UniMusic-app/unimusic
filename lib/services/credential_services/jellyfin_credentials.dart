part of "../credentials_service.dart";

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

  factory JellyfinCredentials.fromJson(Map<String, dynamic> json) {
    return JellyfinCredentials(
      serverUri: json["serverUri"],
      username: json["username"],
      password: json["password"],
      displayName: json["displayName"],
    );
  }

  @override
  int get hashCode => Object.hash(type, serverUri, username);

  @override
  bool operator ==(Object other) =>
      other is JellyfinCredentials &&
      other.serverUri == serverUri &&
      other.username == username;

  @override
  Map<String, dynamic> toJson() => {
    "type": type.id,
    "serverUri": serverUri,
    "username": username,
    "password": password,
    "displayName": displayName,
  };
}
