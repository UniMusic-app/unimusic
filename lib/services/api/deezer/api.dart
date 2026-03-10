import 'dart:convert';
import 'dart:io';

import 'package:blowfish/blowfish.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:unimusic/services/api/deezer/items.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/utils/stream.dart';
import 'package:json_annotation/json_annotation.dart';

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
  // TODO: Implement the incremental favorite fetching (with persistent favorite storage) with checksum
  final Map<MusicItemType, Set<String>> favoriteIds = {
    MusicItemType.song: {},
    MusicItemType.album: {},
    MusicItemType.artist: {},
  };

  DeezerApi({required this.arl, required this.userData})
    : dio = getDio(arl: arl);
  DeezerApi.withDio({
    required this.arl,
    required this.userData,
    required this.dio,
  });

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
      throw Exception("${response.data["error"]}");
    }

    if (response.statusCode! > 200) {
      throw Exception(response.data);
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
      blowfishKey.add(
        songIdMd5.codeUnitAt(i) ^
            songIdMd5.codeUnitAt(i + 16) ^
            key.codeUnitAt(i),
      );
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
      throw Exception("Error: $data");
    }

    final media = data["data"][0]["media"];
    if (media.length == 0) {
      throw Exception("Empty media!: $data");
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

    return (
      response,
      decryptStream(stream: response.data!.stream, blowfishKey: blowfishKey),
    );
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

    final response = await dio.get(
      url,
      options: Options(responseType: ResponseType.stream),
    );

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
    final song = DeezerSong.fromTrack(track);
    return song;
  }

  Stream<DeezerSong> getFavoriteSongs() async* {
    final response = await callMethod("song.getFavoriteIds");
    final songIds = response.data["results"]["data"]
        .map((item) => item["SNG_ID"].toString())
        .toList();

    final songTracksResponse = await callMethod(
      "song.getListData",
      data: {"SNG_IDS": songIds},
    );
    final songTracks = songTracksResponse.data["results"]["data"];

    for (final trackJson in songTracks) {
      final track = DeezerTrack(api: this, trackInfo: trackJson);
      final song = DeezerSong.fromTrack(track, favourite: true);
      favoriteIds[MusicItemType.song]!.add(song.id);
      yield song;
    }
  }

  Stream<DeezerArtist> getFavoriteArtists() async* {
    final profileResponse = await callMethod(
      "deezer.pageProfile",
      data: {"USER_ID": userData.userId, "tab": "artists"},
    );

    final artists = profileResponse.data["results"]["TAB"]["artists"]["data"];

    for (final artistJson in artists) {
      final artist = DeezerArtist.fromDeezerJson(
        api: this,
        json: artistJson,
        favourite: true,
      );
      favoriteIds[MusicItemType.artist]!.add(artist.id);
      yield artist;
    }
  }

  Stream<DeezerAlbum> getFavoriteAlbums() async* {
    final profileResponse = await callMethod(
      "deezer.pageProfile",
      data: {"USER_ID": userData.userId, "tab": "albums"},
    );

    final albums = profileResponse.data["results"]["TAB"]["albums"]["data"];

    for (final albumJson in albums) {
      final album = DeezerAlbum.fromDeezerJson(
        api: this,
        json: albumJson,
        favourite: true,
      );
      favoriteIds[MusicItemType.album]!.add(album.id);
      yield album;
    }
  }

  Future<DeezerAlbum> getAlbum(String albumId) async {
    final pageResponse = await callMethod(
      "deezer.pageAlbum",
      data: {"ALB_ID": albumId, "lang": "en"},
    );

    final results = pageResponse.data["results"];

    final album = DeezerAlbum.fromDeezerJson(api: this, json: results["DATA"]);
    final songs = (results["SONGS"]["data"] as List).map((trackJson) {
      final track = DeezerTrack(api: this, trackInfo: trackJson);
      return DeezerSong.fromTrack(track);
    }).toList();

    album.songs = songs;

    return album;
  }

  Future<List<DeezerSong>> getAlbumSongs(String albumId) async {
    final album = await getAlbum(albumId);
    return album.songs!;
  }

  Future<List<DeezerSong>> getArtistTopSongs(
    String artistId, {
    int? limit,
    int? index,
  }) async {
    final response = await callMethod(
      'artist.getTopTrack',
      data: {
        'ART_ID': artistId,
        if (limit != null) 'nb': limit,
        if (index != null) 'start': index,
      },
    );

    final data = response.data;
    final items = data is Map && data['results'] is Map
        ? data['results']['data']
        : null;
    if (items is! List) {
      throw Exception('Unexpected Deezer GW response: ${response.data}');
    }

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => DeezerSong.fromTrack(
            DeezerTrack(api: this, trackInfo: item),
            favourite: favoriteIds[MusicItemType.song]?.contains(
              item['SNG_ID'].toString(),
            ),
          ),
        )
        .toList();
  }

  Future<List<DeezerAlbum>> getArtistAlbums(
    String artistId, {
    int? limit,
    int? index,
  }) async {
    final response = await callMethod(
      'album.getDiscography',
      data: {
        'ART_ID': artistId,
        'discography_mode': 'all',
        'nb_songs': 0,
        if (limit != null) 'nb': limit,
        if (index != null) 'start': index,
      },
    );

    final data = response.data;
    final items = data is Map && data['results'] is Map
        ? data['results']['data']
        : null;
    if (items is! List) {
      throw Exception('Unexpected Deezer GW response: ${response.data}');
    }

    return items
        .whereType<Map<String, dynamic>>()
        .where((item) {
          final isOfficialAlbum = item['ARTISTS_ALBUMS_IS_OFFICIAL'];
          final isPrimaryArtist = item['ART_ID'].toString() == artistId;
          return isOfficialAlbum && isPrimaryArtist;
        })
        .map(
          (item) => DeezerAlbum.fromDeezerJson(
            api: this,
            json: item,
            favourite: favoriteIds[MusicItemType.album]?.contains(
              item['ALB_ID'].toString(),
            ),
          ),
        )
        .toList();
  }

  Stream<SearchHint> getSearchHints({
    required String query,
    LibraryItemType? itemType,
  }) async* {
    final autocompleteResponse = await dio.get(
      "$searchUrl/autocomplete",
      queryParameters: {"q": query, "limit": 10, "order": "RANKING"},
    );

    final data = autocompleteResponse.data;

    final keys = [
      if (itemType == null || itemType == LibraryItemType.songs) "tracks",
      if (itemType == null || itemType == LibraryItemType.albums) "albums",
      if (itemType == null || itemType == LibraryItemType.artists) "artists",
    ];

    for (final key in keys) {
      if (data[key] == null) continue;

      for (final track in data[key]["data"]) {
        final searchHint = DeezerSearchHint.fromDeezerJson(track);
        if (searchHint != null) {
          yield searchHint;
        }
      }
    }
  }

  Stream<MusicItem> getSearchResults({
    required String query,
    LibraryItemType? itemType,
  }) async* {
    var searchUri = Uri.parse(searchUrl);

    if (itemType != null) {
      final segment = switch (itemType) {
        LibraryItemType.songs => "track",
        LibraryItemType.albums => "album",
        LibraryItemType.artists => "artist",
      };
      searchUri = searchUri.replace(
        pathSegments: [...searchUri.pathSegments, segment],
      );
    }
    searchUri = searchUri.replace(
      queryParameters: {"q": query, "order": "RANKING"},
    );

    final searchResponse = await dio.getUri(searchUri);
    final data = searchResponse.data["data"];

    for (final itemJson in data) {
      // Skip artists that have no albums, most of them seem to be automatically
      // generated collaborations, and noone searchers for those
      if (itemJson["nb_album"] == 0) {
        continue;
      }

      final item = switch (itemJson["type"]) {
        "track" => DeezerSong.fromDeezerJson(api: this, json: itemJson),
        "album" => DeezerAlbum.fromDeezerJson(api: this, json: itemJson),
        "artist" => DeezerArtist.fromDeezerJson(api: this, json: itemJson),
        final type => throw Exception("Unimplemented item type $type"),
      };

      yield item;
    }
  }

  Future<void> removeFavorite(MusicItem item) async {
    switch (item.type) {
      case MusicItemType.song:
        await callMethod('favorite_song.remove', data: {'SNG_ID': item.id});
        break;
      case MusicItemType.album:
        await callMethod('album.deleteFavorite', data: {'ALB_ID': item.id});
        break;
      case MusicItemType.artist:
        await callMethod('artist.deleteFavorite', data: {'ART_ID': item.id});
        break;
    }
    favoriteIds[item.type]!.remove(item.id);
  }

  Future<void> addFavorite(MusicItem item) async {
    switch (item.type) {
      case MusicItemType.song:
        await callMethod('favorite_song.add', data: {'SNG_ID': item.id});
        break;
      case MusicItemType.album:
        await callMethod('album.addFavorite', data: {'ALB_ID': item.id});
        break;
      case MusicItemType.artist:
        await callMethod('artist.addFavorite', data: {'ART_ID': item.id});
        break;
    }
    favoriteIds[item.type]!.add(item.id);
  }

  Future<bool> isFavourite(MusicItem item) async {
    switch (favoriteIds[item.type]) {
      case final Set ids when ids.isNotEmpty:
        return ids.contains(item.id);
      default:
        return switch (item.type) {
          MusicItemType.song => getFavoriteSongs().any(
            (song) => song.id == item.id,
          ),
          MusicItemType.artist => getFavoriteArtists().any(
            (artist) => artist.id == item.id,
          ),
          MusicItemType.album => getFavoriteAlbums().any(
            (album) => album.id == item.id,
          ),
        };
    }
  }
}
