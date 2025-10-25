import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unimusic/services/api/local/shared/items.dart';
import 'package:unimusic/services/database/database.dart';
import 'package:unimusic/services/music_providers/music_provider.dart';
import 'package:unimusic/services/database/cache.dart';
import 'package:image/image.dart' as img;
import 'package:image_size_getter/image_size_getter.dart';
import "package:unimusic/services/api/local/api.dart";

const providerId = "local";

class LocalSharedApi extends LocalApi {
  final List<String> musicDirectories;

  LocalSharedApi({required this.musicDirectories});

  static Future<List<String>> getDefaultMusicDirectories() async {
    final List<String> directories = [];

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        directories.addAll([
          path.join(userProfile, 'Music'),
          path.join(userProfile, 'Documents', 'Music'),
        ]);
      }
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        directories.addAll([path.join(home, 'Music'), path.join(home, 'Documents', 'Music')]);
      }
      debugPrint("Home: $directories");
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        directories.addAll([path.join(home, 'Music'), path.join(home, 'Documents', 'Music')]);
      }
    } else if (Platform.isAndroid) {
      // Android external storage music directories
      directories.addAll([
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/sdcard/Music',
        '/sdcard/Download',
      ]);
    } else if (Platform.isIOS) {
      final directory = (await getApplicationDocumentsDirectory()).path;
      directories.add(directory);

      // We need to create a file in that directory for it to show up for the user
      // That file cannot be hidden
      final file = File('$directory/README.txt');
      await file.writeAsString("Put your Music files here");
    }

    return directories.where((dir) => Directory(dir).existsSync()).toList();
  }

  static const supportedExtensions = {'.mp3', '.flac', '.m4a', '.aac', '.ogg', '.wav', '.wma'};

  Stream<FileSystemEntity> _scanDirectory(String directoryPath) async* {
    try {
      debugPrint("Scanning directory $directoryPath");

      final directory = Directory(directoryPath);
      if (!directory.existsSync()) {
        debugPrint("Directory doesn't exist");
        return;
      }

      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        debugPrint("Got entity ${entity.path}");

        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(extension)) {
            debugPrint("Got ${entity.path}");
            yield entity;
          }
        }
      }
    } catch (error) {
      debugPrint('Error scanning directory $directoryPath: $error');
    }
  }

  Future<AudioMetadata?> _getAudioTags(String filePath) async {
    try {
      final file = File(filePath);
      return readMetadata(file, getImage: true);
    } catch (error) {
      debugPrint('Error reading tags for $filePath: $error');
      return null;
    }
  }

  String _generateSongId(String filePath) {
    return filePath;
  }

  String _generateId(String id) {
    final hash = sha256.convert(id.codeUnits).toString();
    return hash;
  }

  Future<LocalArtist?> _getArtistFromDatabase(String id) async {
    final artistData = await DatabaseHelper.getArtist(id);
    if (artistData == null) return null;
    return LocalArtist.fromDatabase(this, artistData);
  }

  Future<LocalSong?> _createSongFromFile(File file) async {
    try {
      final tags = await _getAudioTags(file.path);
      final fileName = path.basenameWithoutExtension(file.path);
      final songId = _generateSongId(file.path);

      final title = tags?.title?.trim().isNotEmpty == true ? tags!.title! : fileName;
      final albumName = tags?.album?.trim().isNotEmpty == true ? tags!.album! : 'Unknown Album';
      final artistName = tags?.artist?.trim().isNotEmpty == true ? tags!.artist! : 'Unknown Artist';

      // Create or get artist
      final artistId = _generateId('artist:$artistName');
      LocalArtist artist;
      final existingArtistData = await DatabaseHelper.getArtist(artistId);
      if (existingArtistData == null) {
        artist = LocalArtist(api: this, id: artistId, name: artistName, artwork: null);
        await DatabaseHelper.insertArtist(artist);
      } else {
        artist = (await _getArtistFromDatabase(artistId))!;
      }

      // Create or get album
      final albumId = _generateId('album:$albumName:$artistName');
      final existingAlbumData = await DatabaseHelper.getAlbum(albumId);
      if (existingAlbumData == null) {
        final album = LocalAlbum(
          api: this,
          id: albumId,
          name: albumName,
          artists: [artist],
          artwork: null,
        );
        await DatabaseHelper.insertAlbum(album);
      }

      // Get duration from file stats or tags
      final duration = tags?.duration ?? Duration.zero;

      // Create artwork from embedded album art
      LocalArtwork? artwork;
      if (tags?.pictures.isNotEmpty == true) {
        final picture = tags!.pictures.first;
        final pictureSizeResult = ImageSizeGetter.getSizeResult(MemoryInput(picture.bytes));

        // Cache artwork in the different sizes
        for (final size in ArtworkSize.values) {
          String mimeType = picture.mimetype;
          Uint8List bytes = picture.bytes;
          if (pictureSizeResult.size.width > size.width) {
            try {
              final command = img.Command()
                ..decodeImage(picture.bytes)
                ..copyResize(
                  width: size.width.toInt(),
                  maintainAspect: true,
                  interpolation: img.Interpolation.cubic,
                )
                ..encodeJpg(quality: 90);

              final resizedBytes = await command.getBytesThread();
              if (resizedBytes != null) {
                mimeType = "image/jpeg";
                bytes = resizedBytes;
              }
            } catch (error) {
              debugPrint("Failed to resize: $error");
            }
          }

          final filePath = await CacheHelper.saveArtwork(
            songId,
            data: bytes,
            mimeType: mimeType,
            size: size,
          );

          artwork = LocalArtwork(id: songId);

          await DatabaseHelper.insertArtwork(
            artwork,
            filePath: filePath,
            mimeType: mimeType,
            size: size,
          );
        }
      }

      final song = LocalSong(
        api: this,
        id: songId,
        name: title,
        artists: [artist],
        album: albumName,
        duration: duration,
        filePath: file.path,
        artwork: artwork,
      );

      // Insert song into database
      await DatabaseHelper.insertSong(song);

      // Insert album-song relationship
      await DatabaseHelper.insertAlbumSong(albumId, songId);

      return song;
    } catch (error) {
      // TODO: Handle this better?
      debugPrint('Error creating song from file ${file.path}: $error');
      return null;
    }
  }

  Stream<LocalSong> getAllSongs() async* {
    // First check if we have cached songs in database
    final cachedSongs = await DatabaseHelper.getSongsByProvider(providerId);
    final Set<String> processedFiles = {};

    for (final songData in cachedSongs) {
      final song = await LocalSong.fromDatabase(this, songData);
      if (song == null) {
        // TODO: Remove stale data
        continue;
      }
      processedFiles.add(song.filePath);
      yield song;
    }

    debugPrint("Scanning for files in $musicDirectories");

    // Scan for new files
    for (final directory in musicDirectories) {
      await for (final entity in _scanDirectory(directory)) {
        if (entity is! File || processedFiles.contains(entity.path)) {
          continue;
        }

        final song = await _createSongFromFile(entity);
        if (song != null) {
          yield song;
        }
      }
    }
  }

  Stream<LocalAlbum> getAllAlbums() async* {
    // TODO: Add check for recent scans
    // First, scan all songs to populate albums
    await for (final _ in getAllSongs()) {
      // Songs are stored in database during scanning
    }

    // Get all albums from database
    final albumsData = await DatabaseHelper.getAlbumsByProvider(providerId);
    final seenAlbums = <String>{};

    for (final albumData in albumsData) {
      if (seenAlbums.contains(albumData.id)) {
        continue;
      }

      final album = await LocalAlbum.fromDatabase(this, albumData);
      if (album != null) {
        seenAlbums.add(albumData.id);
        yield album;
      }
    }
  }

  Stream<LocalArtist> getAllArtists() async* {
    // First, scan all songs to populate artists
    await for (final _ in getAllSongs()) {
      // Artists are stored in database during scanning
    }

    // Get all artists from database
    final artistsData = await DatabaseHelper.getArtistsByProvider(providerId);
    final seenArtists = <String>{};

    for (final artistData in artistsData) {
      if (seenArtists.contains(artistData.id)) {
        continue;
      }

      final artist = LocalArtist.fromDatabase(this, artistData);
      if (artist != null) {
        seenArtists.add(artistData.id);
        yield artist;
      }
    }
  }

  Stream<LocalSong> getAlbumSongs(String albumId) async* {
    final songData = await DatabaseHelper.getSongsByAlbumId(albumId);
    for (final song in songData) {
      final localSong = await LocalSong.fromDatabase(this, song);
      if (localSong != null) {
        yield localSong;
      }
    }
  }

  Stream<MusicItem> search({
    required String query,
    required Set<LibraryItemType> itemTypes,
  }) async* {
    final lowercaseQuery = query.toLowerCase();

    if (itemTypes.contains(LibraryItemType.songs)) {
      await for (final song in getAllSongs()) {
        if (song.name.toLowerCase().contains(lowercaseQuery) ||
            song.album?.toLowerCase().contains(lowercaseQuery) == true ||
            song.artists.any((artist) => artist.name.toLowerCase().contains(lowercaseQuery))) {
          yield song;
        }
      }
    }

    if (itemTypes.contains(LibraryItemType.albums)) {
      await for (final album in getAllAlbums()) {
        if (album.name.toLowerCase().contains(lowercaseQuery) ||
            album.artists.any((artist) => artist.name.toLowerCase().contains(lowercaseQuery))) {
          yield album;
        }
      }
    }

    if (itemTypes.contains(LibraryItemType.artists)) {
      await for (final artist in getAllArtists()) {
        if (artist.name.toLowerCase().contains(lowercaseQuery)) {
          yield artist;
        }
      }
    }
  }

  Stream<SearchHint> getSearchHints({
    required String query,
    required Set<LibraryItemType> itemTypes,
  }) async* {
    final lowercaseQuery = query.toLowerCase();
    final seenTitles = <String>{};

    if (itemTypes.contains(LibraryItemType.songs)) {
      await for (final song in getAllSongs()) {
        if (song.name.toLowerCase().contains(lowercaseQuery) && !seenTitles.contains(song.name)) {
          seenTitles.add(song.name);
          yield LocalSearchHint(
            title: song.name,
            type: LibraryItemType.songs,
            artwork: song.artwork,
          );
        }
      }
    }

    if (itemTypes.contains(LibraryItemType.albums)) {
      await for (final album in getAllAlbums()) {
        if (album.name.toLowerCase().contains(lowercaseQuery) && !seenTitles.contains(album.name)) {
          seenTitles.add(album.name);
          yield LocalSearchHint(
            title: album.name,
            type: LibraryItemType.albums,
            artwork: album.artwork,
          );
        }
      }
    }

    if (itemTypes.contains(LibraryItemType.artists)) {
      await for (final artist in getAllArtists()) {
        if (artist.name.toLowerCase().contains(lowercaseQuery) &&
            !seenTitles.contains(artist.name)) {
          seenTitles.add(artist.name);
          yield LocalSearchHint(
            title: artist.name,
            type: LibraryItemType.artists,
            artwork: artist.artwork,
          );
        }
      }
    }
  }
}
