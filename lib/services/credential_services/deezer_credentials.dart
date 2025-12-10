part of '../credentials_service.dart';

class DeezerCredentials extends ServiceCredentials {
  final String arl;
  final String? displayName;

  const DeezerCredentials({required this.arl, this.displayName})
    : super(type: ServiceType.deezer);

  @override
  int get hashCode => Object.hash(type, arl);

  @override
  bool operator ==(Object other) =>
      other is DeezerCredentials && other.arl == arl;

  @override
  Map<String, dynamic> toJson() => {
    'type': type.id,
    'arl': arl,
    'displayName': displayName,
  };

  factory DeezerCredentials.fromJson(Map<String, dynamic> json) {
    return DeezerCredentials(
      arl: json['arl'] as String,
      displayName: json['displayName'] as String?,
    );
  }
}
