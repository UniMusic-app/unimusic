import 'dart:convert';
import 'dart:io';

import 'package:blowfish/blowfish.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/material.dart';
import 'package:unimusic/services/api/deezer/items.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/utils/stream.dart';
import 'package:json_annotation/json_annotation.dart';

part "api.g.dart";

const providerId = "deezer";

const deezerUrl = "https://deezer.com";
const getMediaUrl = "https://media.deezer.com/v1/get_url";
const imageCdnUrl = "https://e-cdns-images.dzcdn.net/images";
const searchUrl = "https://api.deezer.com/search";
final gwUri = Uri.parse("https://www.deezer.com/ajax/gw-light.php");

@JsonEnum(valueField: 'value')
enum DeezerSoundFormat {
  flac("FLAC"),
  mp3_128kb("MP3_128"),
  mp3_320kb("MP3_320");

  final String value;
  const DeezerSoundFormat(this.value);

  String toJson() => value;

  String get extension => switch (this) {
    DeezerSoundFormat.flac => "flac",
    _ => "mp3",
  };
}

@JsonSerializable()
class DeezerUserData {
  final String accessToken;
  final String licenseToken;
  final int userId;
  final int timestamp;
  final int expirationTimestamp;

  const DeezerUserData({
    required this.accessToken,
    required this.userId,
    required this.licenseToken,
    required this.expirationTimestamp,
    required this.timestamp,
  });

  factory DeezerUserData.fromJson(Map<String, dynamic> json) => _$DeezerUserDataFromJson(json);
  Map<String, dynamic> toJson() => _$DeezerUserDataToJson(this);

  factory DeezerUserData.fromDeezerJson(Map<String, dynamic> json) {
    final results = json["results"];
    final options = results["USER"]["OPTIONS"];

    final accessToken = results["checkForm"];
    assert(accessToken != null, "ARL expired");

    return DeezerUserData(
      accessToken: accessToken,
      userId: results["USER"]["USER_ID"],
      licenseToken: options["license_token"],
      expirationTimestamp: options["expiration_timestamp"],
      timestamp: options["timestamp"],
    );
  }
}

@JsonSerializable()
class DeezerApi {
  final Dio dio;
  final String arl;
  final DeezerUserData userData;
  final Map<String, Set<String>> favoriteIds = {};

  DeezerApi({required this.arl, required this.userData}) : dio = getDio(arl: arl);
  DeezerApi.withDio({required this.arl, required this.userData, required this.dio});

  factory DeezerApi.fromJson(Map<String, dynamic> json) => _$DeezerApiFromJson(json);
  Map<String, dynamic> toJson() => _$DeezerApiToJson(this);

  static Dio getDio({required String arl}) {
    return Dio(
      BaseOptions(
        baseUrl: deezerUrl,
        followRedirects: true,
        validateStatus: (status) {
          return status != null && status < 500;
        },
        headers: {
          "User-Agent":
              "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15",
          "Cookie": "arl=$arl",
        },
      ),
    )..interceptors.add(CookieManager(CookieJar()));
  }

  static Future<Response> callGwMethod({
    required Dio dio,
    required String method,
    String? accessToken,
    Object? data,
  }) async {
    final response = await dio.postUri(
      Uri(
        scheme: gwUri.scheme,
        host: gwUri.host,
        path: gwUri.path,
        queryParameters: {
          "method": method,
          "api_token": accessToken ?? "",
          "input": "3",
          "api_version": "1.0",
        },
      ),
      data: data,
      options: Options(contentType: "application/json"),
    );

    return response;
  }

  Future<Response> callMethod(String method, {Object? data}) async {
    final response = await DeezerApi.callGwMethod(
      method: method,
      dio: dio,
      accessToken: userData.accessToken,
      data: data,
    );

    if (response.data is Map &&
        response.data?["error"] is Map &&
        response.data?["error"].entries.isNotEmpty) {
      throw Error.safeToString("${response.data["error"]}");
    }

    if (response.statusCode! > 200) {
      throw Error.safeToString(response.data);
    }

    return response;
  }

  static Future<DeezerApi> create({required String arl}) async {
    final dio = getDio(arl: arl);
    final response = await callGwMethod(dio: dio, method: "deezer.getUserData");
    final userData = DeezerUserData.fromDeezerJson(response.data);

    return DeezerApi.withDio(dio: dio, arl: arl, userData: userData);
  }

  // Calculates Blowfish decrypt key for given songId
  List<int> calculateBlowfishKey(String songId) {
    const key = "g4el58wc0zvf9na1";
    final songIdMd5 = md5.convert(utf8.encode(songId)).toString();

    List<int> blowfishKey = [];
    for (int i = 0; i < 16; ++i) {
      blowfishKey.add(songIdMd5.codeUnitAt(i) ^ songIdMd5.codeUnitAt(i + 16) ^ key.codeUnitAt(i));
    }
    return blowfishKey;
  }

  List<int> decryptBlowfish(List<int> data, Blowfish blowfish) {
    return blowfish.decryptCBC(data, [0, 1, 2, 3, 4, 5, 6, 7]);
  }

  Stream<List<int>> decryptStream({
    required Stream<List<int>> stream,
    required List<int> blowfishKey,
  }) async* {
    const chunkSize = 2048;

    final blowfish = newBlowfish(blowfishKey);

    int i = 0;
    await for (final chunk in stream.chunked(chunkSize)) {
      final isEncrypted = (i % 3) == 0;
      final isWholeBlock = chunk.length == chunkSize;

      if (isEncrypted && isWholeBlock) {
        yield decryptBlowfish(chunk, blowfish);
      } else {
        yield chunk;
      }

      i += 1;
    }
  }

  Future<String> getSongUrl({
    required String trackToken,
    required DeezerSoundFormat soundFormat,
    required String licenseToken,
  }) async {
    final response = await dio.post(
      getMediaUrl,
      data: {
        'license_token': licenseToken,
        'media': [
          {
            'type': "FULL",
            "formats": [
              {"cipher": "BF_CBC_STRIPE", "format": soundFormat.toJson()},
            ],
          },
        ],
        'track_tokens': [trackToken],
      },
      options: Options(contentType: "application/json"),
    );

    final data = response.data;
    if (data["data"] == null || data["data"]?[0]?["errors"] != null) {
      throw Error.safeToString("Error: $data");
    }

    final media = data["data"][0]["media"];
    if (media.length == 0) {
      throw Error.safeToString("Empty media!: $data");
    }

    final url = media[0]["sources"][0]["url"];
    return url;
  }

  Future<(Response<ResponseBody>, Stream<List<int>>)> streamSong({
    required String songId,
    required String trackToken,
    required String licenseToken,
    required DeezerSoundFormat soundFormat,
    int? start,
    int? end,
  }) async {
    final url = await getSongUrl(
      trackToken: trackToken,
      licenseToken: licenseToken,
      soundFormat: soundFormat,
    );

    final blowfishKey = calculateBlowfishKey(songId);
    final response = await dio.get<ResponseBody>(
      url,
      options: Options(
        headers: {
          if (start != null && end != null) "Range": "bytes=$start-$end",
          if (start != null && end == null) "Range": "bytes=$start-",
          if (start == null && end != null) "Range": "bytes=-$end",
        },
        responseType: ResponseType.stream,
      ),
    );

    return (response, decryptStream(stream: response.data!.stream, blowfishKey: blowfishKey));
  }

  Future<File> downloadSong({
    required String fileDestination,
    required String songId,
    required String trackToken,
    required String licenseToken,
  }) async {
    final url = await getSongUrl(
      trackToken: trackToken,
      licenseToken: licenseToken,
      soundFormat: DeezerSoundFormat.flac,
    );

    File file = File(fileDestination);
    await file.create(recursive: true);

    final response = await dio.get(url, options: Options(responseType: ResponseType.stream));

    final blowfishKey = calculateBlowfishKey(songId);

    final raf = await file.open(mode: FileMode.writeOnly);
    await for (final chunk in decryptStream(
      stream: response.data.stream,
      blowfishKey: blowfishKey,
    )) {
      await raf.writeFrom(chunk);
    }
    await raf.close();
    return file;
  }

  Future<DeezerTrack> getTrack(String trackId) async {
    final track = await DeezerTrack.fetch(this, trackId);
    return track;
  }

  Future<DeezerSong> getSong(String songId) async {
    final track = await getTrack(songId);
    final song = DeezerSong.fromTrack(api: this, track: track);
    return song;
  }

  Stream<DeezerSong> getFavoriteSongs() async* {
    final songIdResponse = await callMethod("song.getFavoriteIds");
    final songIds = songIdResponse.data["results"]["data"].map((item) => item["SNG_ID"]).toList();

    final songTracksResponse = await callMethod("song.getListData", data: {"sng_ids": songIds});
    final songTracks = songTracksResponse.data["results"]["data"];

    favoriteIds["Song"] = {};

    for (final trackJson in songTracks) {
      final track = DeezerTrack(api: this, trackInfo: trackJson);
      final song = DeezerSong.fromTrack(api: this, track: track, favourite: true);
      favoriteIds["Song"]!.add(song.id);
      yield song;
    }
  }

  Stream<DeezerArtist> getFavoriteArtists() async* {
    final profileResponse = await callMethod(
      "deezer.pageProfile",
      data: {"user_id": userData.userId, "tab": "artists"},
    );

    final artists = profileResponse.data["results"]["TAB"]["artists"]["data"];

    for (final artistJson in artists) {
      final artist = DeezerArtist.fromDeezerJson(this, artistJson);
      yield artist;
    }
  }

  Stream<DeezerAlbum> getFavoriteAlbums() async* {
    final profileResponse = await callMethod(
      "deezer.pageProfile",
      data: {"user_id": userData.userId, "tab": "albums"},
    );

    final albums = profileResponse.data["results"]["TAB"]["albums"]["data"];

    for (final albumJson in albums) {
      final album = DeezerAlbum.fromDeezerJson(this, albumJson);
      yield album;
    }
  }

  Stream<DeezerSong> getAlbumSongs(String albumId) async* {
    final pageResponse = await callMethod(
      "deezer.pageAlbum",
      data: {"alb_id": albumId, "lang": "en"},
    );

    final songTracks = pageResponse.data["results"]["SONGS"]["data"];

    for (final trackJson in songTracks) {
      final track = DeezerTrack(api: this, trackInfo: trackJson);
      final song = DeezerSong.fromTrack(api: this, track: track);
      yield song;
    }
  }

  Stream<SearchHint> getSearchHints({
    required String query,
    required Set<LibraryItemType> itemTypes,
  }) async* {
    final autocompleteResponse = await dio.get(
      "$searchUrl/autocomplete",
      queryParameters: {"q": query, "limit": 10, "order": "RANKING"},
    );

    final data = autocompleteResponse.data;

    const options = [
      (LibraryItemType.songs, "tracks"),
      (LibraryItemType.albums, "albums"),
      (LibraryItemType.artists, "artists"),
    ];

    for (final (itemType, key) in options) {
      if (!itemTypes.contains(itemType) || data[key] == null) continue;

      for (final track in data[key]["data"]) {
        yield DeezerSearchHint.fromDeezerJson(track);
      }
    }
  }

  Stream<MusicItem> getSearchResults({
    required String query,
    required Set<LibraryItemType> itemTypes,
  }) async* {
    final searchResponse = await dio.get(
      searchUrl,
      queryParameters: {"q": query, "order": "RANKING"},
    );

    final data = searchResponse.data["data"];
    for (final itemJson in data) {
      debugPrint("ITEM: ${itemJson["type"]} $itemJson");

      final item = switch (itemJson["type"]) {
        "track" => DeezerSong.fromDeezerJson(this, itemJson),
        "album" => DeezerAlbum.fromDeezerJson(this, itemJson),
        "artist" => DeezerArtist.fromDeezerJson(this, itemJson),
        _ => throw UnimplementedError(),
      };

      debugPrint("Item: $item");

      yield item;
    }
  }

  Future<void> removeFavorites(List<String> ids) async {
    await callMethod("song.removeFavorites", data: {"IDS": ids.join(",")});
  }

  Future<void> addFavorites(List<String> ids) async {
    await callMethod("song.addFavorites", data: {"IDS": ids.join(",")});
  }

  Future<bool> isFavourite(MusicItem item) async {
    switch (favoriteIds[item.type]) {
      case final Set ids when ids.isNotEmpty:
        return ids.contains(item.id);
      default:
        await for (final song in getFavoriteSongs()) {
          if (song.id == item.id) return true;
        }
        return false;
    }
  }
}
