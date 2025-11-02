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
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        directories.addAll([path.join(home, 'Music'), path.join(home, 'Documents', 'Music')]);
      }
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
      if (!await directory.exists()) {
        debugPrint("Directory doesn't exist");
        return;
      }

      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }

        final extension = path.extension(entity.path).toLowerCase();
        if (supportedExtensions.contains(extension)) {
          yield entity;
        }
      }
    } catch (error) {
      debugPrint('Error scanning directory $directoryPath: $error');
    }
  }

  Future<AudioMetadata?> _getAudioTags(File file) async {
    try {
      return readMetadata(file, getImage: true);
    } catch (error) {
      debugPrint('Error reading tags for ${file.path}: $error');
      return null;
    }
  }

  String _generateId(String type, String id) {
    final hash = sha256.convert("$type-$id".codeUnits).toString();
    return hash;
  }

  Future<LocalSong?> _songFromFile(File file) async {
    try {
      final tags = await _getAudioTags(file);

      final songId = _generateId("song", file.path);

      final songData = await DatabaseHelper.getSong(songId);
      if (songData != null) {
        return await LocalSong.fromDatabase(this, songData);
      }

      final fileName = path.basenameWithoutExtension(file.path);

      if (tags == null) {
        final song = LocalSong(
          api: this,
          id: songId,
          name: fileName,
          favourite: false,
          artists: [],
          duration: Duration.zero,
          filePath: file.path,
        );
        await DatabaseHelper.insertSong(song);
        return song;
      }

      final title = tags.title ?? fileName;

      // Create or get artists
      final artistNames = [if (tags.artist != null) tags.artist!, ...tags.performers];
      final artists = <LocalArtist>[];
      for (final artistName in artistNames) {
        final artistId = _generateId("artist", artistName);

        final existingArtistData = await DatabaseHelper.getArtist(artistId);

        final LocalArtist artist;
        if (existingArtistData == null) {
          artist = LocalArtist(api: this, id: artistId, name: artistName, favourite: false);
          await DatabaseHelper.insertArtist(artist);
        } else {
          artist = LocalArtist.fromDatabase(this, existingArtistData);
        }
        artists.add(artist);
      }

      // Create or get album
      final albumName = tags.album;
      LocalAlbum? album;
      if (albumName != null) {
        final albumId = _generateId("album", albumName);

        final existingAlbumData = await DatabaseHelper.getAlbum(albumId);
        if (existingAlbumData == null) {
          album = LocalAlbum(
            api: this,
            id: albumId,
            name: albumName,
            favourite: false,
            artists: artists,
          );
          await DatabaseHelper.insertAlbum(album);
        } else {
          album = await LocalAlbum.fromDatabase(this, existingAlbumData);
        }
      }

      // Get duration from file stats or tags
      // TODO: In case duration isn't extracted support setting it during initial playback?
      final duration = tags.duration ?? Duration.zero;

      // Create artwork from embedded album art
      LocalArtwork? artwork;
      final picture = tags.pictures.firstOrNull;
      if (picture != null) {
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
        favourite: false,
        artists: artists,
        album: album?.name,
        duration: duration,
        filePath: file.path,
        artwork: artwork,
      );

      // Insert song into database
      await DatabaseHelper.insertSong(song);

      // Insert album-song relationship
      if (album != null) {
        await DatabaseHelper.insertAlbumSong(album.id, songId);
      }

      return song;
    } catch (error) {
      // TODO: Handle this better?
      debugPrint('Error creating song from file ${file.path}: $error');
      return null;
    }
  }

  @override
  Stream<LocalSong> getAllSongs() async* {
    // First check if we have cached songs in database
    final cachedSongs = await DatabaseHelper.getSongsByProvider(providerId);
    final Set<String> processedFiles = {};

    for (final songData in cachedSongs) {
      final song = await LocalSong.fromDatabase(this, songData);
      processedFiles.add(song.filePath!);
      yield song;
    }

    debugPrint("Scanning for files in $musicDirectories");

    // TODO: Remove stale data
    // Scan for new files
    for (final directory in musicDirectories) {
      await for (final entity in _scanDirectory(directory)) {
        if (entity is! File || processedFiles.contains(entity.path)) {
          continue;
        }

        final song = await _songFromFile(entity);
        if (song != null) {
          yield song;
        }
      }
    }
  }

  @override
  Stream<LocalAlbum> getAllAlbums() async* {
    final albumsData = await DatabaseHelper.getAlbumsByProvider(providerId);

    for (final albumData in albumsData) {
      final album = await LocalAlbum.fromDatabase(this, albumData);
      yield album;
    }
  }

  @override
  Stream<LocalArtist> getAllArtists() async* {
    final artistsData = await DatabaseHelper.getArtistsByProvider(providerId);
    final seenArtists = <String>{};

    for (final artistData in artistsData) {
      if (seenArtists.contains(artistData.id)) {
        continue;
      }

      final artist = LocalArtist.fromDatabase(this, artistData);
      seenArtists.add(artistData.id);
      yield artist;
    }
  }

  Stream<LocalSong> getAlbumSongs(String albumId) async* {
    final songData = await DatabaseHelper.getSongsByAlbumId(albumId);
    for (final song in songData) {
      final localSong = await LocalSong.fromDatabase(this, song);
      yield localSong;
    }
  }

  @override
  Stream<MusicItem> getSearchResults({required String query, LibraryItemType? itemType}) async* {
    final lowercaseQuery = query.toLowerCase();

    if (itemType == null || itemType == LibraryItemType.songs) {
      await for (final song in getAllSongs()) {
        if (song.name.toLowerCase().contains(lowercaseQuery) ||
            song.album?.toLowerCase().contains(lowercaseQuery) == true ||
            song.artists.any((artist) => artist.name.toLowerCase().contains(lowercaseQuery))) {
          yield song;
        }
      }
    }

    if (itemType == null || itemType == LibraryItemType.albums) {
      await for (final album in getAllAlbums()) {
        if (album.name.toLowerCase().contains(lowercaseQuery) ||
            album.artists.any((artist) => artist.name.toLowerCase().contains(lowercaseQuery))) {
          yield album;
        }
      }
    }

    if (itemType == null || itemType == LibraryItemType.artists) {
      await for (final artist in getAllArtists()) {
        if (artist.name.toLowerCase().contains(lowercaseQuery)) {
          yield artist;
        }
      }
    }
  }

  @override
  Stream<SearchHint> getSearchHints({required String query, LibraryItemType? itemType}) async* {
    final lowercaseQuery = query.toLowerCase();

    if (itemType == null || itemType == LibraryItemType.songs) {
      await for (final song in getAllSongs()) {
        if (song.name.toLowerCase().contains(lowercaseQuery)) {
          yield LocalSearchHint(
            title: song.name,
            type: LibraryItemType.songs,
            artwork: song.artwork,
          );
        }
      }
    }

    if (itemType == null || itemType == LibraryItemType.albums) {
      await for (final album in getAllAlbums()) {
        if (album.name.toLowerCase().contains(lowercaseQuery)) {
          yield LocalSearchHint(
            title: album.name,
            type: LibraryItemType.albums,
            artwork: album.artwork,
          );
        }
      }
    }

    if (itemType == null || itemType == LibraryItemType.artists) {
      await for (final artist in getAllArtists()) {
        if (artist.name.toLowerCase().contains(lowercaseQuery)) {
          yield LocalSearchHint(
            title: artist.name,
            type: LibraryItemType.artists,
            artwork: artist.artwork,
          );
        }
      }
    }
  }

  @override
  Future<void> cleanupGarbage() async {
    final dbSongs = await DatabaseHelper.getSongsByProvider(providerId);
    for (final dbSong in dbSongs) {
      if (dbSong.filePath == null || !await File(dbSong.filePath!).exists()) {
        await DatabaseHelper.deleteSong(dbSong.id);
      }
    }

    final dbAlbums = await DatabaseHelper.getAlbumsByProvider(providerId);
    for (final dbAlbum in dbAlbums) {
      final albumSongs = await DatabaseHelper.getSongsByAlbumId(dbAlbum.id);
      if (albumSongs.isEmpty) {
        await DatabaseHelper.deleteAlbum(dbAlbum.id);
      }
    }

    final dbArtists = await DatabaseHelper.getArtistsByProvider(providerId);
    for (final dbArtist in dbArtists) {
      final artistSongs = await DatabaseHelper.getSongsByArtist(dbArtist.id);
      final artistAlbums = await DatabaseHelper.getAlbumsByArtist(dbArtist.id);
      if (artistSongs.isEmpty && artistAlbums.isEmpty) {
        await DatabaseHelper.deleteArtist(dbArtist.id);
      }
    }

    await DatabaseHelper.cleanupOrphanedArtworks();
  }
}
