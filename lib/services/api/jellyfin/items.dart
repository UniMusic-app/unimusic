import 'package:unimusic/services/api/jellyfin/api.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/services/database/cached_artwork.dart';
import 'package:just_audio/just_audio.dart';

mixin JellyfinItemWithFavourite implements MusicItem {
  JellyfinApi get api;

  @override
  Future<bool> isFavourite() async {
    return favourite;
  }

  @override
  Future<void> toggleFavourite(bool value) async {
    if (value) {
      await api.addToFavorites(id);
      favourite = true;
    } else {
      await api.removeFromFavorites(id);
      favourite = false;
    }
  }
}

class JellyfinArtwork extends CachedArtwork {
  final JellyfinApi api;
  final String type;
  final String? tag;

  const JellyfinArtwork({required this.api, required this.type, this.tag, required super.id})
    : super(providerId: providerId);

  @override
  String getMimeType() => 'image/jpeg';

  @override
  Uri getImageUri(ArtworkSize size) {
    return api.imageUri(itemId: id, type: type, tag: tag, width: size.width.toInt(), quality: 90);
  }
}

class JellyfinArtist extends Artist<JellyfinArtwork> with JellyfinItemWithFavourite {
  @override
  final JellyfinApi api;

  JellyfinArtist({
    required this.api,

    required super.id,
    required super.name,
    required super.favourite,
    super.artwork,
  }) : super(providerId: providerId);

  JellyfinArtist.fromJellyfinJson(JellyfinApi api, Map<String, dynamic> json)
    : this(
        api: api,
        id: json["Id"],
        name: json["Name"],
        // In case JellyfinArtist is created as a subArtist, UserData.IsFavorite will be null
        favourite: json["UserData"]?["IsFavorite"] ?? false,
        artwork: json["ImageTags"]?["Primary"] != null
            ? JellyfinArtwork(
                api: api,
                id: json["Id"],
                type: "Primary",
                tag: json["ImageTags"]?["Primary"],
              )
            : null,
      );
}

// FIXME: Inherit albums artwork in case song is missing one
class JellyfinSong extends Song<JellyfinArtist, JellyfinArtwork> with JellyfinItemWithFavourite {
  @override
  final JellyfinApi api;

  JellyfinSong({
    required this.api,
    required super.id,
    required super.name,
    required super.artists,
    required super.album,
    required super.duration,
    required super.favourite,
    super.artwork,
  }) : super(providerId: providerId);

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
}

class JellyfinAlbum extends Album<JellyfinArtist, JellyfinArtwork> with JellyfinItemWithFavourite {
  @override
  final JellyfinApi api;

  JellyfinAlbum({
    required this.api,
    required super.id,
    required super.name,
    required super.artists,
    required super.favourite,
    super.artwork,
  }) : super(providerId: providerId);

  factory JellyfinAlbum.fromJellyfinJson(JellyfinApi api, Map<String, dynamic> json) {
    return JellyfinAlbum(
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
    );
  }

  @override
  Stream<Song> getSongs() async* {
    yield* api.items(includeItemTypes: {JellyfinItemType.audio}, albumIds: {id}).cast();
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
