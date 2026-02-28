import 'package:dio/dio.dart';
import 'package:unimusic/services/api/deezer/api.dart';
import 'package:unimusic/services/api/deezer/items.dart';
import 'package:unimusic/utils/stream.dart';
import 'package:just_audio/just_audio.dart';

class DeezerAudioSource extends StreamAudioSource {
  final DeezerSong song;
  final DeezerSoundFormat soundFormat;

  Response<ResponseBody>? fullResponse;
  ReplayableStream? fullStream;

  DeezerAudioSource({required this.song, required this.soundFormat, super.tag});

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    if (fullResponse == null || fullStream == null) {
      final (response, stream) = await song.stream(
        soundFormat: soundFormat,
        start: 0,
      );
      fullStream = ReplayableStream(stream);
      fullResponse = response;
    }

    final contentType = fullResponse!.data!.headers["content-type"]![0];
    final sourceLength = int.parse(
      fullResponse!.data!.headers["content-range"]![0].split("/")[1],
    );

    if (start == null || end == null) {
      Stream<List<int>> stream = fullStream!.stream();
      if (start != null) stream = stream.skipBytes(start);
      if (end != null) stream = stream.skipBytes(end);

      return StreamAudioResponse(
        contentLength: sourceLength,
        contentType: contentType,
        sourceLength: sourceLength,

        offset: start ?? 0,
        stream: stream,
      );
    }

    end -= 1;

    final contentLength = end - start + 1;
    final stream = fullStream!.stream().skipBytes(start).takeBytes(end + 1);

    return StreamAudioResponse(
      contentLength: contentLength,
      contentType: contentType,
      sourceLength: sourceLength,

      offset: start,
      stream: stream,
    );
  }
}
