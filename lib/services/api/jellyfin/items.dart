import 'package:flutter/material.dart';
import 'package:unimusic/services/api/jellyfin/api.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:just_audio/just_audio.dart';

part "items.g.dart";

@JsonSerializable()
class JellyfinArtwork extends Artwork {
  final JellyfinApi api;
  final String type;
  final String? tag;

  const JellyfinArtwork({required super.id, required this.api, required this.type, this.tag});

  factory JellyfinArtwork.fromJson(Map<String, dynamic> json) => _$JellyfinArtworkFromJson(json);
  Map<String, dynamic> toJson() => _$JellyfinArtworkToJson(this);

  @override
  Uri getImageUri({int? width, int? height, int? quality}) {
    final imageUri = api.imageUri(
      itemId: id,
      type: type,
      tag: tag,
      width: width,
      height: height,
      quality: quality,
    );
    return imageUri;
  }

  @override
  ImageProvider getImage({int? width, int? height, int? quality}) {
    final imageUri = getImageUri(width: width, height: height, quality: quality);
    return NetworkImage(imageUri.toString());
  }
}

@JsonSerializable()
class JellyfinArtist extends Artist<JellyfinArtwork> {
  JellyfinArtist({required super.id, required super.name, super.artwork, super.favourite})
    : super(providerId: providerId);

  factory JellyfinArtist.fromJson(Map<String, dynamic> json) => _$JellyfinArtistFromJson(json);
  Map<String, dynamic> toJson() => _$JellyfinArtistToJson(this);

  JellyfinArtist.fromJellyfinJson(JellyfinApi api, Map<String, dynamic> json)
    : this(
        id: json["Id"],
        name: json["Name"],
        artwork: json["ImageTags"]?["Primary"] != null
            ? JellyfinArtwork(
                api: api,
                id: json["Id"],
                type: "Primary",
                tag: json["ImageTags"]?["Primary"],
              )
            : null,
      );

  @override
  Future<bool> isFavourite() async {
    // TODO: isFavourite
    return false;
  }

  @override
  Future<void> toggleFavourite(bool value) async {
    // TODO: toggleFavourite
  }
}

// FIXME: Inherit albums artwork in case song is missing one
@JsonSerializable()
class JellyfinSong extends Song<JellyfinArtist, JellyfinArtwork> {
  final JellyfinApi api;

  JellyfinSong({
    required this.api,
    required super.id,
    required super.name,
    required super.artists,
    required super.album,
    required super.duration,
    super.favourite,
    super.artwork,
  }) : super(providerId: providerId);

  factory JellyfinSong.fromJson(Map<String, dynamic> json) => _$JellyfinSongFromJson(json);
  Map<String, dynamic> toJson() => _$JellyfinSongToJson(this);

  JellyfinSong.fromJellyfinJson(JellyfinApi api, Map<String, dynamic> json)
    : this(
        api: api,
        id: json["Id"],
        name: json["Name"],
        favourite: json["UserData"]["IsFavorite"],
        artists: (json["ArtistItems"] as List)
            .map((json) => JellyfinArtist.fromJellyfinJson(api, json))
            .toList()
            .cast<JellyfinArtist>(),
        artwork: json["ImageTags"]?["Primary"] != null
            ? JellyfinArtwork(
                api: api,
                id: json["Id"],
                type: "Primary",
                tag: json["ImageTags"]?["Primary"],
              )
            : null,
        album: json["Album"],
        duration: Duration(
          microseconds: ((json["RunTimeTicks"] as int) / ticksInMicroseconds).toInt(),
        ),
      );

  @override
  Future<AudioSource> getAudioSource() async {
    return api.audio(song: this);
  }

  @override
  Future<bool> isFavourite() async {
    if (favourite != null) {
      return favourite!;
    }

    final response = await api.fetch(pathSegments: ["Items", id]);
    return response.data["UserData"]["IsFavourite"];
  }

  @override
  Future<void> toggleFavourite(bool value) async {
    super.toggleFavourite(value);
    if (value) {
      api.addToFavorites(id);
      debugPrint("Favorited $id");
    } else {
      api.removeFromFavorites(id);
      debugPrint("Removed from favorites $id");
    }
  }
}

@JsonSerializable()
class JellyfinAlbum extends Album<JellyfinArtist, JellyfinArtwork> {
  final JellyfinApi api;

  JellyfinAlbum({
    required this.api,
    required super.id,
    required super.name,
    required super.artists,
    super.artwork,
    super.favourite,
  }) : super(providerId: providerId);

  factory JellyfinAlbum.fromJson(Map<String, dynamic> json) => _$JellyfinAlbumFromJson(json);
  Map<String, dynamic> toJson() => _$JellyfinAlbumToJson(this);

  JellyfinAlbum.fromJellyfinJson(JellyfinApi api, Map<String, dynamic> json)
    : this(
        api: api,
        id: json["Id"],
        name: json["Name"],
        artists: (json["ArtistItems"] as List)
            .map((json) => JellyfinArtist.fromJellyfinJson(api, json))
            .toList()
            .cast<JellyfinArtist>(),
        artwork: json["ImageTags"]?["Primary"] != null
            ? JellyfinArtwork(
                api: api,
                id: json["Id"],
                type: "Primary",
                tag: json["ImageTags"]?["Primary"],
              )
            : null,
      );

  @override
  Stream<Song> getSongs() async* {
    yield* api.items(includeItemTypes: {JellyfinItemType.audio}, albumIds: {id}).cast();
  }

  @override
  Future<bool> isFavourite() async {
    // TODO: isFavourite
    return false;
  }

  @override
  Future<void> toggleFavourite(bool value) async {
    // TODO: toggleFavourite
  }
}

class JellyfinSearchHint extends SearchHint {
  const JellyfinSearchHint({required super.title, required super.type, super.artwork});

  static JellyfinSearchHint? fromJellyfinJson(JellyfinApi api, Map<String, dynamic> json) {
    return JellyfinSearchHint(
      title: json["Name"],
      type: switch (json["Type"]) {
        "Audio" => LibraryItemType.songs,
        "MusicAlbum" => LibraryItemType.albums,
        "MusicArtist" => LibraryItemType.artists,
        final type => throw UnimplementedError("$type"),
      },
      artwork: json["PrimaryImageTag"] != null
          ? JellyfinArtwork(
              api: api,
              id: json["ItemId"],
              type: "Primary",
              tag: json["PrimaryImageTag"],
            )
          : null,
    );
  }
}
