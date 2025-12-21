package app.unimusic.android

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import app.unimusic.android.MediaStoreType

enum class MediaStoreType {
  Int,
  Long,
  String,
  Double,
}

class MediaStorePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private var activity: Activity? = null
  private var pendingResult: Result? = null

  private companion object {
    const val PERMISSION_REQUEST_CODE = 1001
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "media_store")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    println("Calling ${call.method}");
    when (call.method) {
      "getSongs" -> getItems(call, result, ::querySongs)
      "getArtists" -> getItems(call, result, ::queryArtists)
      "getAlbums" -> getItems(call, result, ::queryAlbums)
      "getAlbumSongs" -> getItems(call, result, ::queryAlbumSongs)
      "checkPermission" -> result.success(checkPermission())
      "requestPermission" -> requestPermission(result)
      "readArtwork" -> readArtwork(call.argument("artworkUri"), result)
      else -> result.notImplemented()
    }
  }

  private fun readArtwork(artworkUri: String?, result: Result) {
    if (artworkUri == null)  {
      result.error("MISSING_ARGUMENT", "You have to provide 'artworkUri' argument to readArtwork() method call", null);
      return
    }

    val uri = Uri.parse(artworkUri) ?: run {
      result.error("ERROR", "Failed to parse URI $artworkUri", null);
      return;
    }

    val activity = activity ?: run {
      result.error("ACTIVITY_NULL", "Activity is null", null)
      return
    }

    try {
      val input = activity.contentResolver.openInputStream(uri)!!
      val bytes = input.readBytes()
      input.close()
      result.success(bytes)
    } catch (e: Exception) {
      result.error("ERROR", "Failed to read uri $artworkUri: $e", null);
    }
  }

  private fun checkPermission(): Boolean {
    val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      Manifest.permission.READ_MEDIA_AUDIO
    } else {
      Manifest.permission.READ_EXTERNAL_STORAGE
    }

    return activity?.let {
      ContextCompat.checkSelfPermission(it, permission) == PackageManager.PERMISSION_GRANTED
    } ?: false
  }

  private fun requestPermission(result: Result) {
    val currentActivity = activity
    if (currentActivity == null) {
      result.error("NO_ACTIVITY", "Activity is null", null)
      return
    }

    if (checkPermission()) {
      result.success(true)
      return
    }

    if (pendingResult != null) {
      result.error("ALREADY_PENDING", "A permission request is already in progress", null)
      return
    }

    pendingResult = result

    val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      arrayOf(
        Manifest.permission.READ_MEDIA_AUDIO,
        Manifest.permission.READ_MEDIA_IMAGES,
      )
    } else {
      arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
    }

    try {
      androidx.core.app.ActivityCompat.requestPermissions(currentActivity, permissions, PERMISSION_REQUEST_CODE)
    } catch (t: Throwable) {
      pendingResult?.error("ERROR", "Failed to request permissions: ${t.message}", null)
      pendingResult = null
    }
  }

  private fun attachToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity

    binding.addRequestPermissionsResultListener { requestCode, _, grantResults ->
      if (requestCode != PERMISSION_REQUEST_CODE) return@addRequestPermissionsResultListener false

      val pr = pendingResult ?: return@addRequestPermissionsResultListener false
      val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }

      pr.success(granted)
      pendingResult = null
      true
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    attachToActivity(binding)
  }

  private fun query(
    activity: Activity,
    fields: Map<String, Pair<String, MediaStoreType>>,
    uri: Uri,
    sortOrder: String? = null,
    selection: String? = null,
    selectionArgs: Array<String>? = null
  ): MutableList<MutableMap<String, Any?>> {
    val projection = fields.values.map { it.first }.toTypedArray();

    val cursor = activity.contentResolver.query(
      uri,
      projection,
      selection,
      selectionArgs,
      sortOrder
    ) ?: throw Exception("Failed to get songs: cursor is null");

    val items = mutableListOf<MutableMap<String, Any?>>()

    while (cursor.moveToNext()) {
      val item = mutableMapOf<String, Any?>()
      for ((key, columnInfo) in fields) {
        val (column, columnType) = columnInfo
        val index = cursor.getColumnIndexOrThrow(column)

        val value = when (columnType) {
          MediaStoreType.Long -> cursor.getLong(index)
          MediaStoreType.Int -> cursor.getInt(index)
          MediaStoreType.Double -> cursor.getDouble(index)
          MediaStoreType.String -> cursor.getString(index)
        }

        item.put(key, value)
      }
      items.add(item)
    }

    cursor.close()

    return items
  }


  @Suppress("UNUSED_PARAMETER")
  private fun queryArtists(_call: MethodCall, activity: Activity): MutableList<MutableMap<String, Any?>> {
    val artistFields = mapOf(
      "id" to (MediaStore.Audio.Artists._ID to MediaStoreType.Long),
      "name" to (MediaStore.Audio.Media.ARTIST to MediaStoreType.String),
    )
    return query(
      activity,
      artistFields,
      MediaStore.Audio.Artists.EXTERNAL_CONTENT_URI,
      sortOrder =MediaStore.Audio.Artists.ARTIST,
    );
  }

  @Suppress("UNUSED_PARAMETER")
  private fun queryAlbums(_call: MethodCall, activity: Activity): MutableList<MutableMap<String, Any?>> {
    val albumFields = mapOf(
      "id" to (MediaStore.Audio.Albums._ID to MediaStoreType.Long),
      "name" to (MediaStore.Audio.Albums.ALBUM to MediaStoreType.String),
      "artist" to (MediaStore.Audio.Albums.ARTIST to MediaStoreType.String),
      "artistId" to (MediaStore.Audio.Albums.ARTIST_ID to MediaStoreType.Long),
      // "artwork" added reactively
    )

    val albums = query(
      activity,
      albumFields,
      MediaStore.Audio.Albums.EXTERNAL_CONTENT_URI,
      sortOrder = MediaStore.Audio.Albums.ALBUM,
    );

    // Add album artworks if they exist
    albums.forEach { album ->
      runCatching {
        val albumArtUri = ContentUris.withAppendedId(
          Uri.parse("content://media/external/audio/albumart"),
          album["id"] as Long
        )
        activity.contentResolver.openInputStream(albumArtUri)?.close()
        album["artwork"] = albumArtUri.toString()
      }
    }
    return albums
  }

  private fun subQuerySongs(
    activity: Activity,
    sortOrder: String? = null,
    selection: String? = null,
    selectionArgs: Array<String>? = null,
  ): MutableList<MutableMap<String, Any?>> {
    val songFields = mapOf(
      "id" to (MediaStore.Audio.Media._ID to MediaStoreType.Long),
      "name" to (MediaStore.Audio.Media.TITLE to MediaStoreType.String),
      "duration" to (MediaStore.Audio.Media.DURATION to MediaStoreType.Long),
      "artist" to (MediaStore.Audio.Media.ARTIST to MediaStoreType.String),
      "artistId" to (MediaStore.Audio.Media.ARTIST_ID to MediaStoreType.Long),
      "album" to (MediaStore.Audio.Media.ALBUM to MediaStoreType.String),
      "albumId" to (MediaStore.Audio.Media.ALBUM_ID to MediaStoreType.Long),
      "albumArtist" to (MediaStore.Audio.Media.ALBUM_ARTIST to MediaStoreType.String),
      "albumDisc" to (MediaStore.Audio.Media.DISC_NUMBER to MediaStoreType.Int),
      "albumTrack" to (MediaStore.Audio.Media.CD_TRACK_NUMBER to MediaStoreType.Int),
      "mimeType" to (MediaStore.Audio.Media.MIME_TYPE to MediaStoreType.String),
      // "path" added reactively
      // "artwork" added reactively
    );

    val songs = query(
      activity,
      songFields,
      MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
      sortOrder,
      selection,
      selectionArgs,
    );

    // Add artworks from album if they exist
    songs.forEach { song ->
      runCatching {
        val songUri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, song["id"] as Long);
        activity.contentResolver.openInputStream(songUri)?.close()
        song["path"] = songUri.toString();

        val albumArtUri = ContentUris.withAppendedId(
          Uri.parse("content://media/external/audio/albumart"),
          song["albumId"] as Long
        )
        activity.contentResolver.openInputStream(albumArtUri)?.close()
        song["artwork"] = albumArtUri.toString()
      }
    }

    return songs;
  }

  private fun queryAlbumSongs(call: MethodCall, activity: Activity): MutableList<MutableMap<String, Any?>> {
    val albumId = call.argument<String>("albumId") ?: throw Exception("queryAlbumSongs required 'albumId' to be set");
    return subQuerySongs(
      activity,
      sortOrder = "${MediaStore.Audio.Media.DISC_NUMBER} ASC, ${MediaStore.Audio.Media.TRACK} ASC",
      selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.ALBUM_ID} = ?",
      selectionArgs = arrayOf(albumId.toString())
    )
  }

  @Suppress("UNUSED_PARAMETER")
  private fun querySongs(_call: MethodCall, activity: Activity): MutableList<MutableMap<String, Any?>> {
    return subQuerySongs(
      activity,
      sortOrder = MediaStore.Audio.Media.TITLE,
      selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0",
    )
  }

  private fun getItems(call: MethodCall, result: Result, query: (call: MethodCall, activity: Activity) -> MutableList<MutableMap<String, Any?>> ) {
    if (!checkPermission()) {
      result.error("PERMISSION_DENIED", "Storage permission not granted", null)
      return
    }

    val activity = activity ?: run {
      result.error("ACTIVITY_NULL", "Activity is null", null)
      return
    }

    try {
      val items = query(call, activity);
      result.success(items)
    } catch (e: Throwable) {
      result.error("ERROR", "Failed to retrieve items: ${e.message}", null)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
    pendingResult?.error("ACTIVITY_DETACHED", "Activity detached before permission result returned", null)
    pendingResult = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    attachToActivity(binding)
  }

  override fun onDetachedFromActivity() {
    activity = null
    pendingResult?.error("ACTIVITY_DETACHED", "Activity detached before permission result returned", null)
    pendingResult = null
  }
}
