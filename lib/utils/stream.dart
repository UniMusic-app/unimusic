extension ChunkedStream<T> on Stream<List<T>> {
  Stream<List<T>> chunked(int chunkSize) async* {
    List<T> buffer = [];

    await for (final data in this) {
      buffer.addAll(data);

      while (buffer.length >= chunkSize) {
        yield buffer.sublist(0, chunkSize);
        buffer = buffer.sublist(chunkSize);
      }
    }

    if (buffer.isNotEmpty) {
      yield buffer;
    }
  }
}

extension ChunkifyStream<T> on Stream<T> {
  Stream<List<T>> chunkify(int chunkSize) async* {
    List<T> buffer = [];

    await for (final data in this) {
      buffer.add(data);

      while (buffer.length >= chunkSize) {
        yield buffer.sublist(0, chunkSize);
        buffer = buffer.sublist(chunkSize);
      }
    }

    if (buffer.isNotEmpty) {
      yield buffer;
    }
  }
}

extension SkipBytes on Stream<List<int>> {
  Stream<List<int>> skipBytes(int bytesAmount) async* {
    int remaining = bytesAmount;

    await for (final chunk in this) {
      if (remaining == 0) {
        // Already skipped enough; just yield remaining chunks
        yield chunk;
        continue;
      }

      if (chunk.length <= remaining) {
        // Skip this entire chunk
        remaining -= chunk.length;
      } else {
        // Skip part of this chunk
        yield chunk.sublist(remaining);
        remaining = 0;
      }
    }
  }
}

extension TakeBytes on Stream<List<int>> {
  Stream<List<int>> takeBytes(int bytesAmount) async* {
    int remaining = bytesAmount;

    await for (final chunk in this) {
      if (remaining <= 0) break;

      if (chunk.length <= remaining) {
        yield chunk;
        remaining -= chunk.length;
      } else {
        // Emit only part of the chunk
        yield chunk.sublist(0, remaining);
        remaining = 0;
        break; // Stop reading once we've got enough
      }
    }
  }
}

extension FlattenStream<T> on Stream<Iterable<T>> {
  Stream<T> flatten() async* {
    await for (final items in this) {
      for (final item in items) {
        yield item;
      }
    }
  }
}

class ReplayableStream {
  late final Stream<List<int>> _source;
  final List<int> buffer = [];

  ReplayableStream(Stream<List<int>> source) {
    _source = source.asBroadcastStream();
    _source.listen(
      (chunk) => buffer.addAll(chunk),
      onDone: () {},
      onError: (e, st) {},
      cancelOnError: false,
    );
  }

  Stream<List<int>> stream() async* {
    yield* Stream.value(buffer);
    yield* _source;
  }
}
