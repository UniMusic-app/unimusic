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

  @override
  Future<bool> isFavourite() async {
    return favourite ?? api.isFavourite(this);
  }

  @override
  Future<void> toggleFavourite(bool value) async {
    super.toggleFavourite(value);
    if (value) {
      await api.addFavorites([id]);
      favourite = true;
    } else {
      await api.removeFavorites([id]);
      favourite = false;
    }
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
  String? get trackToken => trackInfo["TRACK_TOKEN"];

  List<DeezerArtist>? get artists => switch (trackInfo["ARTISTS"]) {
    List<dynamic> artists =>
      artists.map((artist) => DeezerArtist.fromDeezerJson(api, artist)).toList(),
    _ => null,
  };

  DeezerArtwork? get artistArtwork => switch (trackInfo["ART_PICTURE"]) {
    String id => DeezerArtwork.withType(id: id, imageType: "artist"),
    _ => null,
  };

  DeezerArtwork? get albumArtwork => switch (trackInfo["ALB_PICTURE"]) {
    String id => DeezerArtwork.withType(id: id, imageType: "cover"),
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

  String? trackToken;
  DateTime? trackTokenExpire;

  DeezerSong({
    required this.api,
    required super.id,
    required super.name,
    required super.artists,
    required super.album,
    required super.duration,
    super.artwork,
    super.favourite,
    this.trackToken,
    this.trackTokenExpire,
  }) : super(providerId: providerId);

  DeezerSong.fromTrack({required DeezerApi api, required DeezerTrack track, bool? favourite})
    : this(
        api: api,
        id: track.id!,
        name: track.title!,
        artists: track.artists!,
        album: track.album!,
        duration: track.duration!,
        trackToken: track.trackToken,
        trackTokenExpire: track.trackTokenExpire,
        artwork: track.albumArtwork,
      );

  DeezerSong.fromDeezerJson(DeezerApi api, Map<String, dynamic> json)
    : this(
        api: api,
        id: json["id"].toString(),
        name: json["title"],
        album: json["album"]["title"],
        artists: [DeezerArtist.fromDeezerJson(api, json["artist"])],
        duration: Duration(seconds: json["duration"]),
        artwork: DeezerArtwork.withType(id: json["md5_image"], imageType: "cover"),
      );

  Future<(Response<ResponseBody>, Stream<List<int>>)> stream({
    required DeezerSoundFormat soundFormat,
    int? start,
    int? end,
  }) async {
    if (trackTokenExpire == null || DateTime.now().toUtc().isAfter(trackTokenExpire!)) {
      debugPrint("Refresh track token!");
      final track = await api.getTrack(id);
      trackToken = track.id!;
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
}

class DeezerArtwork extends CachedArtwork {
  const DeezerArtwork({required super.id}) : super(providerId: providerId);
  const DeezerArtwork.withType({required String id, required String imageType})
    : this(id: "$imageType/$id");

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
    super.favourite,
  }) : super(providerId: providerId);

  factory DeezerArtist.fromDeezerJson(DeezerApi api, Map<String, dynamic> json) {
    if (json["id"] != null) {
      return DeezerArtist(
        api: api,
        id: json["id"].toString(),
        name: json["name"],
        artwork: switch (json["md5_image"]) {
          String id => DeezerArtwork.withType(id: id, imageType: "artist"),
          _ => null,
        },
      );
    }

    return DeezerArtist(
      api: api,
      id: json["ART_ID"],
      name: json["ART_NAME"],
      artwork: DeezerArtwork.withType(id: json["ART_PICTURE"], imageType: "artist"),
    );
  }
}

class DeezerAlbum extends Album<DeezerArtist, DeezerArtwork> with DeezerFavouriteItem {
  @override
  final DeezerApi api;

  DeezerAlbum({
    required this.api,
    required super.id,
    required super.name,
    required super.artists,
    super.artwork,
    super.favourite,
  }) : super(providerId: providerId);

  factory DeezerAlbum.fromDeezerJson(DeezerApi api, Map<String, dynamic> json) {
    if (json["id"] != null) {
      return DeezerAlbum(
        api: api,
        id: json["id"].toString(),
        name: json["title"],
        artwork: DeezerArtwork.withType(id: json["md5_image"], imageType: "cover"),
        artists: [DeezerArtist.fromDeezerJson(api, json["artist"])],
      );
    }

    return DeezerAlbum(
      api: api,
      id: json["ALB_ID"],
      name: json["ALB_TITLE"],
      artwork: DeezerArtwork.withType(id: json["ALB_PICTURE"], imageType: "cover"),
      artists: [DeezerArtist(api: api, id: json["ART_ID"], name: json["ART_NAME"])],
    );
  }

  @override
  Stream<Song> getSongs() async* {
    yield* api.getAlbumSongs(id);
  }
}

class DeezerSearchHint extends SearchHint {
  const DeezerSearchHint({required super.title, super.artwork, super.type});

  DeezerSearchHint.fromDeezerJson(Map<String, dynamic> json)
    : this(
        title: json["title"],
        type: switch (json["type"]) {
          "track" => LibraryItemType.songs,
          "artist" => LibraryItemType.artists,
          "album" => LibraryItemType.albums,
          _ => throw UnimplementedError(),
        },
        artwork: DeezerArtwork.withType(
          id: json["md5_image"],
          imageType: json["type"] == "artist" ? "artist" : "cover",
        ),
      );
}
