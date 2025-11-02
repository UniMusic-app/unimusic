import 'dart:io';
import 'dart:typed_data';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:unimusic/main.dart';
import 'package:unimusic/services/api/jellyfin/items.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/utils/string.dart';

const providerId = "jellyfin";

const ticksInMicroseconds = 10; // 1 tick=100ns, 1μs=1000ns

final dio = Dio(
  BaseOptions(
    followRedirects: true,
    validateStatus: (status) {
      return status != null && status < 500;
    },
  ),
);

class JellyfinApi {
  final Uri serverUri;
  final JellyfinUser user;
  final String authenticationHeader;

  JellyfinApi({required this.serverUri, required this.user, required this.authenticationHeader});

  Future<void> addToFavorites(String itemId) async {
    await fetch(pathSegments: ["UserFavoriteItems", itemId], method: "POST");
  }

  Stream<MusicItem> artists({
    Set<JellyfinSortBy> sortBy = const {},
    JellyfinSortOrder sortOrder = JellyfinSortOrder.ascending,
    bool recursive = true,
  }) async* {
    final response = await fetch(
      pathSegments: ["Artists"],
      queryParameters: {
        "recursive": recursive.toString(),
        "sortBy": sortBy.map((sortType) => sortType.toJson()).join(","),
        "sortOrder": sortOrder.toJson(),
      },
    );

    final data = response.data;
    if (data is! Map) {
      debugPrint("Failed to decode response data");
      return;
    }

    for (final item in data["Items"]) {
      yield JellyfinArtist.fromJellyfinJson(this, item);
    }
  }

  Future<AudioSource> audio({required JellyfinSong song}) async {
    final uri = _uri(pathSegments: ["Items", song.id, "File"]);
    final headers = {HttpHeaders.authorizationHeader: authenticationHeader};

    return ProgressiveAudioSource(
      uri,
      headers: headers,
      tag: MediaItem(
        id: song.id,
        title: song.name,
        album: song.album,
        artist: song.artists.formatted,
        duration: song.duration,
        artHeaders: headers,
        artUri: song.artwork?.getImageUri(ArtworkSize.medium),
      ),
      options: ProgressiveAudioSourceOptions(
        // Required to make FLAC files not seek behind the actual position
        darwinAssetOptions: DarwinAssetOptions(preferPreciseDurationAndTiming: true),
      ),
    );
  }

  Future<Response<dynamic>> fetch({
    required List<String> pathSegments,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? method,
  }) async {
    final uri = _uri(pathSegments: pathSegments, queryParameters: queryParameters);
    final response = await dio.requestUri(
      uri,
      options: Options(
        method: method ?? "GET",
        headers: {HttpHeaders.authorizationHeader: authenticationHeader, ...?headers},
      ),
    );
    return response;
  }

  Future<Uint8List?> image({
    required String itemId,
    required String type,
    String format = "jpeg",
    String? tag,
    int? width,
    int? height,
    int? quality,
  }) async {
    final uri = imageUri(
      itemId: itemId,
      type: type,
      format: format,
      tag: tag,
      width: width,
      height: height,
      quality: quality,
    );

    Uint8List? bytes;
    try {
      final response = await dio.getUri(uri, options: Options(responseType: ResponseType.bytes));

      bytes = response.data;
    } catch (error) {
      debugPrint("Failed fetching image $itemId: $error");
    }

    return bytes;
  }

  Uri imageUri({
    required String itemId,
    required String type,
    String format = "jpeg",
    String? tag,
    int? width,
    int? height,
    int? quality,
  }) {
    final uri = _uri(
      pathSegments: ["Items", itemId, "Images", type],
      queryParameters: {
        "format": format,
        if (tag != null) "tag": tag,
        if (width != null) "width": width.toString(),
        if (height != null) "height": height.toString(),
        if (quality != null) "quality": quality.toString(),
      },
    );
    return uri;
  }

  Future<MusicItem> item(String itemId) async {
    final response = await fetch(pathSegments: ["Items", itemId]);
    final item = response.data;
    switch (JellyfinItemType.fromJson(item["Type"])) {
      case JellyfinItemType.audio:
        return JellyfinSong.fromJellyfinJson(this, item);
      case JellyfinItemType.musicAlbum:
        return JellyfinAlbum.fromJellyfinJson(this, item);
      case JellyfinItemType.musicArtist:
        return JellyfinArtist.fromJellyfinJson(this, item);
      default:
        throw UnimplementedError();
    }
  }

  Stream<MusicItem> items({
    bool recursive = true,

    JellyfinSortOrder sortOrder = JellyfinSortOrder.ascending,
    Set<JellyfinItemType>? includeItemTypes,
    Set<JellyfinSortBy>? sortBy,

    String? searchTerm,
    int? limit,
    int? startIndex,

    Set<String>? ids,
    Set<String>? albumIds,
    Set<String>? artistIds,

    bool? isFavourite,
  }) async* {
    final response = await fetch(
      pathSegments: ["Items"],
      queryParameters: {
        "recursive": recursive.toString(),
        "sortOrder": sortOrder.toJson(),
        if (includeItemTypes != null)
          "includeItemTypes": includeItemTypes.map((itemType) => itemType.toJson()).join(","),
        if (sortBy != null) "sortBy": sortBy.map((sortType) => sortType.toJson()).join(","),
        if (searchTerm != null) "searchTerm": searchTerm,
        if (limit != null) "limit": limit.toString(),
        if (startIndex != null) "startIndex": startIndex.toString(),
        if (albumIds != null) "albumIds": albumIds.join(","),
        if (ids != null) "ids": ids.join(","),
        if (artistIds != null) "artistIds": artistIds.join(","),
        if (isFavourite != null) "isFavorite": isFavourite.toString(),
      },
    );

    final data = response.data;
    if (data is! Map) {
      debugPrint("Failed to decode response data");
      return;
    }

    for (final item in data["Items"]) {
      switch (JellyfinItemType.fromJson(item["Type"])) {
        case JellyfinItemType.audio:
          yield JellyfinSong.fromJellyfinJson(this, item);
        case JellyfinItemType.musicAlbum:
          yield JellyfinAlbum.fromJellyfinJson(this, item);
        case JellyfinItemType.musicArtist:
          yield JellyfinArtist.fromJellyfinJson(this, item);
        default:
          throw UnimplementedError();
      }
    }
  }

  Future<void> removeFromFavorites(String itemId) async {
    await fetch(pathSegments: ["UserFavoriteItems", itemId], method: "DELETE");
  }

  Stream<SearchHint> searchHints({
    required String searchTerm,
    Set<JellyfinItemType>? includeItemTypes,
    String? parentId,
  }) async* {
    final response = await fetch(
      pathSegments: ["Search", "Hints"],
      queryParameters: {
        "searchTerm": searchTerm,
        if (includeItemTypes != null) "includeItemTypes": includeItemTypes.join(","),
        if (parentId != null) "parentId": parentId,
      },
    );

    final data = response.data;
    if (data is! Map) {
      debugPrint("Failed to decode response data");
      return;
    }

    for (final item in data["SearchHints"]) {
      final searchHint = JellyfinSearchHint.fromJellyfinJson(this, item);
      if (searchHint != null) yield searchHint;
    }
  }

  Uri _uri({required List<String> pathSegments, Map<String, String>? queryParameters}) {
    return Uri(
      scheme: serverUri.scheme,
      host: serverUri.host,
      port: serverUri.port,
      pathSegments: serverUri.pathSegments + pathSegments,
      queryParameters: queryParameters,
    );
  }

  static Future<JellyfinApi> authenticateByName({
    required Uri serverUri,
    String? username,
    String? password,
  }) async {
    final uri = Uri(
      scheme: serverUri.scheme,
      host: serverUri.host,
      port: serverUri.port,
      pathSegments: serverUri.pathSegments + ["Users", "AuthenticateByName"],
    );

    final response = await dio.postUri(
      uri,
      data: {"Username": username, if (password != null) "Pw": password},
      options: Options(
        headers: {HttpHeaders.authorizationHeader: await generateAuthorizationHeader()},
      ),
    );

    final user = JellyfinUser.fromJellyfinJson(response.data);
    final api = JellyfinApi.authenticateByUser(serverUri, user);
    return api;
  }

  static Future<JellyfinApi> authenticateByUser(Uri serverUri, JellyfinUser user) async {
    return JellyfinApi(
      serverUri: serverUri,
      user: user,
      authenticationHeader: await generateAuthorizationHeader(accessToken: user.accessToken),
    );
  }

  static Future<String> generateAuthorizationHeader({String? accessToken}) async {
    final deviceInfo = DeviceInfoPlugin();

    final String device;
    final String deviceId;
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      device = info.model;
      final androidId = AndroidId();
      deviceId = (await androidId.getId())!;
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      device = info.model;
      deviceId = info.identifierForVendor!;
    } else if (Platform.isLinux) {
      final info = await deviceInfo.linuxInfo;
      device = info.name;
      deviceId = info.machineId!;
    } else if (Platform.isWindows) {
      final info = await deviceInfo.windowsInfo;
      device = info.computerName;
      deviceId = info.deviceId;
    } else if (Platform.isMacOS) {
      final info = await deviceInfo.macOsInfo;
      device = info.modelName;
      deviceId = info.systemGUID!;
    } else {
      throw Exception("Unimplemented");
    }

    var authorizationHeaderParts = [
      'Client="$appName"',
      'Device="$device"',
      'DeviceId="$deviceId"',
      'Version="$appVersion"',
    ];

    if (accessToken != null) {
      authorizationHeaderParts.add('Token=""$accessToken');
    }

    return "MediaBrowser ${authorizationHeaderParts.join(", ")}";
  }
}

enum JellyfinItemType {
  aggregateFolder,
  audio,
  audioBook,
  basePluginFolder,
  book,
  boxSet,
  channel,
  channelFolderItem,
  collectionFolder,
  episode,
  folder,
  genre,
  manualPlaylistsFolder,
  movie,
  liveTvChannel,
  liveTvProgram,
  musicAlbum,
  musicArtist,
  musicGenre,
  musicVideo,
  person,
  photo,
  photoAlbum,
  playlist,
  playlistsFolder,
  program,
  recording,
  season,
  series,
  studio,
  trailer,
  tvChannel,
  tvProgram,
  userRootFolder,
  userView,
  video,
  year;

  String toJson() => name.capitalized;

  static JellyfinItemType fromJson(String itemType) {
    return values.byName(itemType.uncapitalized);
  }

  static JellyfinItemType fromLibraryItemType(LibraryItemType itemType) {
    return switch (itemType) {
      LibraryItemType.songs => JellyfinItemType.audio,
      LibraryItemType.albums => JellyfinItemType.musicAlbum,
      LibraryItemType.artists => JellyfinItemType.musicArtist,
    };
  }
}

enum JellyfinSortBy {
  airedEpisodeOrder,
  album,
  albumArtist,
  artist,
  dateCreated,
  officialRating,
  datePlayed,
  premiereDate,
  startDate,
  sortName,
  name,
  random,
  runtime,
  communityRating,
  productionYear,
  playCount,
  criticRating,
  isFolder,
  isUnplayed,
  isPlayed,
  seriesSortName,
  videoBitRate,
  airTime,
  studio,
  isFavoriteOrLiked,
  dateLastContentAdded,
  seriesDatePlayed,
  parentIndexNumber,
  indexNumber;

  String toJson() => this.name.capitalized;

  static JellyfinSortBy fromJson(String itemType) {
    return values.byName(itemType.uncapitalized);
  }
}

enum JellyfinSortOrder {
  ascending,
  descending;

  String toJson() => name.capitalized;

  static JellyfinSortOrder fromJson(String itemType) {
    return values.byName(itemType.uncapitalized);
  }
}

class JellyfinUser {
  final String id;
  final String name;
  final String serverId;
  final String accessToken;

  const JellyfinUser({
    required this.id,
    required this.name,
    required this.serverId,
    required this.accessToken,
  });

  JellyfinUser.fromJellyfinJson(Map<String, dynamic> json)
    : this(
        id: json["User"]["Id"],
        name: json["User"]["Name"],
        serverId: json["User"]["ServerId"],
        accessToken: json["AccessToken"],
      );
}
