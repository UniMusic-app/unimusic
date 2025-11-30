import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:unimusic/services/api/deezer/api.dart';
import 'package:unimusic/services/api/deezer/audio_source.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/services/database/cached_artwork.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

mixin DeezerFavouriteItem on MusicItem {
  DeezerApi get api;
  bool clientChanged = false;

  @override
  Future<bool> isFavourite() async {
    if (clientChanged) {
      return favourite;
    }

    // TODO: Try to get favourite some better way?
    favourite = await api.isFavourite(this);
    return favourite;
  }

  @override
  Future<void> toggleFavourite(bool value) async {
    if (value) {
      await api.addFavorite(this);
      favourite = true;
    } else {
      await api.removeFavorite(this);
      favourite = false;
    }
    clientChanged = true;
  }
}

class DeezerTrack {
  final DeezerApi api;
  final Map<String, dynamic> trackInfo;

  const DeezerTrack({required this.api, required this.trackInfo});

  static Future<DeezerTrack> fetch(DeezerApi api, String trackId) async {
    final response = await api.callMethod("deezer.pageTrack", data: {"SNG_ID": trackId});

    if (response.data['results']['DATA']['MD5_ORIGIN'] == null) {
      throw Exception("TOKEN EXPIRED");
    }

    return DeezerTrack(api: api, trackInfo: response.data["results"]["DATA"]);
  }

  String? get id => trackInfo["SNG_ID"];
  String? get title => trackInfo["SNG_TITLE"];
  String? get album => trackInfo["ALB_TITLE"];
  String? get albumId => trackInfo["ALB_ID"];
  String? get trackToken => trackInfo["TRACK_TOKEN"];

  List<DeezerArtist>? get artists => switch (trackInfo["ARTISTS"]) {
    List<dynamic> artists =>
      artists.map((artist) => DeezerArtist.fromDeezerJson(api: api, json: artist)).toList(),
    _ => null,
  };

  DeezerArtwork? get artistArtwork => switch (trackInfo["ART_PICTURE"]) {
    String id => DeezerArtwork.withType(id: id, type: "artist"),
    _ => null,
  };

  DeezerArtwork? get albumArtwork => switch (trackInfo["ALB_PICTURE"]) {
    String id => DeezerArtwork.withType(id: id, type: "cover"),
    _ => null,
  };

  DateTime? get trackTokenExpire {
    if (trackInfo["TRACK_TOKEN_EXPIRE"] == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(trackInfo["TRACK_TOKEN_EXPIRE"] * 1000);
  }

  Duration? get duration {
    if (trackInfo["DURATION"] == null) {
      return null;
    }
    return Duration(seconds: int.parse(trackInfo["DURATION"]));
  }
}

class DeezerSong extends Song<DeezerArtist, DeezerArtwork> with DeezerFavouriteItem {
  @override
  final DeezerApi api;

  String? albumId;

  String? trackToken;
  DateTime? trackTokenExpire;

  DeezerSong({
    required this.api,
    this.albumId,
    this.trackToken,
    this.trackTokenExpire,

    required super.id,
    required super.name,
    required super.artists,
    required super.album,
    required super.duration,
    super.artwork,

    bool? favourite,
  }) : super(
         providerId: providerId,
         favourite: favourite ?? api.favoriteIds["Song"]?.contains(id) ?? false,
       );

  DeezerSong.fromTrack(DeezerTrack track, {bool? favourite})
    : this(
        api: track.api,
        id: track.id!,
        name: track.title!,
        artists: track.artists!,
        album: track.album!,
        albumId: track.albumId,
        duration: track.duration!,
        trackToken: track.trackToken,
        trackTokenExpire: track.trackTokenExpire,
        artwork: track.albumArtwork,
      );

  DeezerSong.fromDeezerJson({
    required DeezerApi api,
    required Map<String, dynamic> json,
    bool? favourite,
  }) : this(
         api: api,
         id: json["id"].toString(),
         name: json["title"],
         album: json["album"]["title"],
         favourite: favourite,
         artists: [DeezerArtist.fromDeezerJson(api: api, json: json["artist"])],
         duration: Duration(seconds: json["duration"]),
         artwork: DeezerArtwork.withType(id: json["md5_image"], type: "cover"),
       );

  Future<(Response<ResponseBody>, Stream<List<int>>)> stream({
    required DeezerSoundFormat soundFormat,
    int? start,
    int? end,
  }) async {
    if (trackTokenExpire == null || DateTime.now().toUtc().isAfter(trackTokenExpire!)) {
      debugPrint("Refresh track token!");
      final track = await api.getTrack(id);
      trackToken = track.trackToken!;
      trackTokenExpire = track.trackTokenExpire!;
    }

    return api.streamSong(
      soundFormat: soundFormat,
      songId: id,
      trackToken: trackToken!,
      licenseToken: api.userData.licenseToken,
      start: start,
      end: end,
    );
  }

  @override
  Future<AudioSource> getAudioSource() async {
    return DeezerAudioSource(
      song: this,
      soundFormat: DeezerSoundFormat.mp3_128kb,
      tag: MediaItem(
        id: id,
        title: name,
        album: album,
        artist: artists.formatted,
        artUri: artwork?.getImageUri(ArtworkSize.medium),
        duration: duration,
      ),
    );
  }

  @override
  Future<Album?> getAlbum() async {
    if (albumId == null) {
      return null;
    }

    final album = await api.getAlbum(albumId!);
    return album;
  }
}

class DeezerArtwork extends CachedArtwork {
  const DeezerArtwork({required super.id}) : super(providerId: providerId);

  const DeezerArtwork.withType({required String id, required String type}) : this(id: "$type/$id");

  factory DeezerArtwork.fromPictureUrl(String url) {
    final uri = Uri.parse(url);
    final parts = uri.pathSegments; // ["images", type, id, ...]
    return DeezerArtwork.withType(type: parts[1], id: parts[2]);
  }

  @override
  String getMimeType() => 'image/jpeg';

  @override
  Uri getImageUri(ArtworkSize size) {
    final quality = 80;
    final width = size.width.toInt();
    final height = width;
    return Uri.parse("$imageCdnUrl/$id/${height}x$width-000000-$quality-0-0.jpg");
  }
}

class DeezerArtist extends Artist<DeezerArtwork> with DeezerFavouriteItem {
  @override
  final DeezerApi api;

  DeezerArtist({
    required this.api,
    required super.id,
    required super.name,
    super.artwork,
    bool? favourite,
  }) : super(
         providerId: providerId,
         favourite: favourite ?? api.favoriteIds["Song"]?.contains(id) ?? false,
       );

  factory DeezerArtist.fromDeezerJson({
    required DeezerApi api,
    required Map<String, dynamic> json,
    bool? favourite,
  }) {
    if (json["id"] != null) {
      return DeezerArtist(
        api: api,
        id: json["id"].toString(),
        name: json["name"],
        favourite: favourite,
        artwork: DeezerArtwork.fromPictureUrl(json["picture_xl"]),
      );
    }

    return DeezerArtist(
      api: api,
      id: json["ART_ID"],
      name: json["ART_NAME"],
      artwork: DeezerArtwork.withType(id: json["ART_PICTURE"], type: "artist"),
    );
  }
}

class DeezerAlbum extends Album<DeezerArtist, DeezerArtwork> with DeezerFavouriteItem {
  @override
  final DeezerApi api;
  List<DeezerSong>? songs;

  DeezerAlbum({
    required this.api,
    required super.id,
    required super.name,
    required super.artists,
    this.songs,
    super.artwork,
    bool? favourite,
  }) : super(
         providerId: providerId,
         favourite: favourite ?? api.favoriteIds["Song"]?.contains(id) ?? false,
       );

  factory DeezerAlbum.fromDeezerJson({
    required DeezerApi api,
    required Map<String, dynamic> json,
    bool? favourite,
  }) {
    if (json["id"] != null) {
      return DeezerAlbum(
        api: api,
        id: json["id"].toString(),
        name: json["title"],
        favourite: favourite,
        artwork: DeezerArtwork.withType(id: json["md5_image"], type: "cover"),
        artists: [DeezerArtist.fromDeezerJson(api: api, json: json["artist"])],
      );
    }

    return DeezerAlbum(
      api: api,
      id: json["ALB_ID"],
      name: json["ALB_TITLE"],
      favourite: favourite,
      artwork: DeezerArtwork.withType(id: json["ALB_PICTURE"], type: "cover"),
      artists: [DeezerArtist(api: api, id: json["ART_ID"], name: json["ART_NAME"])],
    );
  }

  @override
  Stream<Song> getSongs() async* {
    if (this.songs != null) {
      yield* Stream.fromIterable(this.songs!);
      return;
    }

    final songs = await api.getAlbumSongs(id);
    this.songs = songs;
    yield* Stream.fromIterable(songs);
  }
}

class DeezerSearchHint extends SearchHint {
  const DeezerSearchHint({required super.title, super.artwork, super.type});

  static DeezerSearchHint? fromDeezerJson(Map<String, dynamic> json) {
    switch (json["type"]) {
      case "artist":
        if (json["nb_album"] == "0") {
          return null;
        }
        return DeezerSearchHint.fromArtistDeezerJson(json);
      case "album":
        return DeezerSearchHint.fromAlbumDeezerJson(json);
      case "track":
        return DeezerSearchHint.fromTrackDeezerJson(json);
      default:
        debugPrint("Unknown deezer search hint type ${json['type']}");
        return null;
    }
  }

  DeezerSearchHint.fromArtistDeezerJson(Map<String, dynamic> json)
    : this(
        title: json["name"],
        type: LibraryItemType.artists,
        artwork: DeezerArtwork.fromPictureUrl(json["picture_xl"]),
      );

  DeezerSearchHint.fromAlbumDeezerJson(Map<String, dynamic> json)
    : this(
        title: json["title"],
        type: LibraryItemType.albums,
        artwork: DeezerArtwork.withType(id: json["md5_image"], type: "cover"),
      );

  DeezerSearchHint.fromTrackDeezerJson(Map<String, dynamic> json)
    : this(
        title: json["title"],
        type: LibraryItemType.songs,
        artwork: DeezerArtwork.withType(id: json["md5_image"], type: "cover"),
      );
}
