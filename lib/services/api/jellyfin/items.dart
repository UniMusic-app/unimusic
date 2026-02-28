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

  const JellyfinArtwork({
    required this.api,
    required this.type,
    this.tag,
    required super.id,
  }) : super(providerId: providerId);

  @override
  String getMimeType() => 'image/jpeg';

  @override
  Uri getImageUri(ArtworkSize size) {
    return api.imageUri(
      itemId: id,
      type: type,
      tag: tag,
      width: size.width.toInt(),
      quality: 90,
    );
  }
}

class JellyfinStreamInfo {
  final String? container;
  final String? codec;
  final int? bitRate;
  final int? sampleRate;
  final int? channels;

  const JellyfinStreamInfo({
    this.container,
    this.codec,
    this.bitRate,
    this.sampleRate,
    this.channels,
  });

  static JellyfinStreamInfo? fromPlaybackInfo(Map<String, dynamic> data) {
    final sources = data["MediaSources"];
    if (sources is! List || sources.isEmpty) {
      return null;
    }

    final source = sources.first;
    if (source is! Map) {
      return null;
    }

    Map<String, dynamic>? audioStream;
    final streams = source["MediaStreams"];
    if (streams is List) {
      for (final entry in streams) {
        if (entry is Map && entry["Type"] == "Audio") {
          audioStream = Map<String, dynamic>.from(entry);
          break;
        }
      }
    }

    final container = source["Container"] as String?;
    final codec = audioStream?["Codec"] as String?;

    final bitRate =
        _parseInt(audioStream?["BitRate"]) ?? _parseInt(source["BitRate"]);
    final sampleRate = _parseInt(audioStream?["SampleRate"]);
    final channels = _parseInt(audioStream?["Channels"]);

    return JellyfinStreamInfo(
      container: container,
      codec: codec,
      bitRate: bitRate,
      sampleRate: sampleRate,
      channels: channels,
    );
  }
}

class JellyfinArtist extends Artist<JellyfinArtwork>
    with JellyfinItemWithFavourite {
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
class JellyfinSong extends Song<JellyfinArtist, JellyfinArtwork>
    with JellyfinItemWithFavourite {
  final String? albumId;
  JellyfinStreamInfo? _streamInfo;

  @override
  final JellyfinApi api;

  JellyfinSong({
    required this.api,
    required this.albumId,

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
        albumId: json["AlbumId"],
        duration: Duration(
          microseconds: ((json["RunTimeTicks"] as int) / ticksInMicroseconds)
              .toInt(),
        ),
      );

  @override
  Future<AudioSource> getAudioSource() async {
    return api.audio(song: this);
  }

  Future<JellyfinStreamInfo?> getStreamInfo() async {
    if (_streamInfo != null) {
      return _streamInfo;
    }

    final info = await api.playbackInfo(id);
    if (info == null) {
      return null;
    }

    _streamInfo = JellyfinStreamInfo.fromPlaybackInfo(info);
    return _streamInfo;
  }

  @override
  Future<Album?> getAlbum() async {
    if (albumId == null) {
      return null;
    }

    final album = await api.item(albumId!) as Album;
    return album;
  }

  @override
  Future<StreamInfoParts?> getStreamInfoParts() async {
    final info = await getStreamInfo();
    if (info == null) return null;

    final format = (info.codec?.trim().isNotEmpty ?? false)
        ? info.codec!.toUpperCase()
        : info.container?.toUpperCase();
    final bitrateKbps = info.bitRate != null
        ? (info.bitRate! / 1000).round()
        : null;

    return (
      format: format,
      bitrateKbps: bitrateKbps,
      sampleRateHz: info.sampleRate,
    );
  }
}

class JellyfinAlbum extends Album<JellyfinArtist, JellyfinArtwork>
    with JellyfinItemWithFavourite {
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

  factory JellyfinAlbum.fromJellyfinJson(
    JellyfinApi api,
    Map<String, dynamic> json,
  ) {
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
    yield* api
        .items(includeItemTypes: {JellyfinItemType.audio}, albumIds: {id})
        .cast();
  }
}

class JellyfinSearchHint extends SearchHint {
  const JellyfinSearchHint({
    required super.title,
    required super.type,
    super.artwork,
  });

  static JellyfinSearchHint? fromJellyfinJson(
    JellyfinApi api,
    Map<String, dynamic> json,
  ) {
    final LibraryItemType type;
    switch (json["Type"]) {
      case "Audio":
        type = LibraryItemType.songs;
        break;
      case "MusicAlbum":
        type = LibraryItemType.albums;
        break;
      case "MusicArtist":
        type = LibraryItemType.artists;
        break;
      default:
        return null;
    }

    return JellyfinSearchHint(
      title: json["Name"],
      type: type,
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

int? _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
