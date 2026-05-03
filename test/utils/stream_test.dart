import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:unimusic/utils/stream.dart";

void main() {
  group("ChunkedStream (Stream<List<T>>).chunked", () {
    test("chunks evenly divisible data", () async {
      final stream = Stream.fromIterable([
        [1, 2, 3, 4],
        [5, 6, 7, 8],
      ]);
      final result = await stream.chunked(4).toList();
      expect(result, [
        [1, 2, 3, 4],
        [5, 6, 7, 8],
      ]);
    });

    test("chunks data across input boundaries", () async {
      final stream = Stream.fromIterable([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      final result = await stream.chunked(2).toList();
      expect(result, [
        [1, 2],
        [3, 4],
        [5, 6],
      ]);
    });

    test("yields remainder when not evenly divisible", () async {
      final stream = Stream.fromIterable([
        [1, 2, 3, 4, 5],
      ]);
      final result = await stream.chunked(3).toList();
      expect(result, [
        [1, 2, 3],
        [4, 5],
      ]);
    });

    test("empty stream yields nothing", () async {
      const stream = Stream<List<int>>.empty();
      final result = await stream.chunked(3).toList();
      expect(result, isEmpty);
    });

    test("single element chunks", () async {
      final stream = Stream.fromIterable([
        [1, 2, 3],
      ]);
      final result = await stream.chunked(1).toList();
      expect(result, [
        [1],
        [2],
        [3],
      ]);
    });
  });

  group("ChunkifyStream (Stream<T>).chunkify", () {
    test("chunks individual items", () async {
      final stream = Stream.fromIterable([1, 2, 3, 4, 5, 6]);
      final result = await stream.chunkify(3).toList();
      expect(result, [
        [1, 2, 3],
        [4, 5, 6],
      ]);
    });

    test("yields remainder", () async {
      final stream = Stream.fromIterable([1, 2, 3, 4, 5]);
      final result = await stream.chunkify(3).toList();
      expect(result, [
        [1, 2, 3],
        [4, 5],
      ]);
    });

    test("empty stream yields nothing", () async {
      const stream = Stream<int>.empty();
      final result = await stream.chunkify(3).toList();
      expect(result, isEmpty);
    });

    test("chunk size of 1", () async {
      final stream = Stream.fromIterable([1, 2, 3]);
      final result = await stream.chunkify(1).toList();
      expect(result, [
        [1],
        [2],
        [3],
      ]);
    });
  });

  group("SkipBytes", () {
    test("skips exact number of bytes", () async {
      final stream = Stream.fromIterable([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      final result = await stream.skipBytes(3).toList();
      expect(result, [
        [4, 5, 6],
      ]);
    });

    test("skips partial chunk", () async {
      final stream = Stream.fromIterable([
        [1, 2, 3, 4, 5],
      ]);
      final result = await stream.skipBytes(2).toList();
      expect(result, [
        [3, 4, 5],
      ]);
    });

    test("skips across chunk boundaries", () async {
      final stream = Stream.fromIterable([
        [1, 2],
        [3, 4],
        [5, 6],
      ]);
      final result = await stream.skipBytes(3).toList();
      expect(result, [
        [4],
        [5, 6],
      ]);
    });

    test("skip zero bytes yields all data", () async {
      final stream = Stream.fromIterable([
        [1, 2, 3],
      ]);
      final result = await stream.skipBytes(0).toList();
      expect(result, [
        [1, 2, 3],
      ]);
    });

    test("skip more bytes than available yields nothing", () async {
      final stream = Stream.fromIterable([
        [1, 2, 3],
      ]);
      final result = await stream.skipBytes(10).toList();
      expect(result, isEmpty);
    });
  });

  group("TakeBytes", () {
    test("takes exact number of bytes", () async {
      final stream = Stream.fromIterable([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      final result = await stream.takeBytes(3).toList();
      expect(result, [
        [1, 2, 3],
      ]);
    });

    test("takes partial chunk", () async {
      final stream = Stream.fromIterable([
        [1, 2, 3, 4, 5],
      ]);
      final result = await stream.takeBytes(2).toList();
      expect(result, [
        [1, 2],
      ]);
    });

    test("takes across chunk boundaries", () async {
      final stream = Stream.fromIterable([
        [1, 2],
        [3, 4],
        [5, 6],
      ]);
      final result = await stream.takeBytes(3).toList();
      expect(result, [
        [1, 2],
        [3],
      ]);
    });

    test("take zero bytes yields nothing", () async {
      final stream = Stream.fromIterable([
        [1, 2, 3],
      ]);
      final result = await stream.takeBytes(0).toList();
      expect(result, isEmpty);
    });

    test("take more bytes than available yields all", () async {
      final stream = Stream.fromIterable([
        [1, 2, 3],
      ]);
      final result = await stream.takeBytes(10).toList();
      expect(result, [
        [1, 2, 3],
      ]);
    });
  });

  group("FlattenStream", () {
    test("flattens nested iterables", () async {
      final stream = Stream.fromIterable([
        [1, 2, 3],
        [4, 5],
        [6],
      ]);
      final result = await stream.flatten().toList();
      expect(result, [1, 2, 3, 4, 5, 6]);
    });

    test("handles empty inner iterables", () async {
      final stream = Stream<List<int>>.fromIterable([
        [1, 2],
        [],
        [3],
      ]);
      final result = await stream.flatten().toList();
      expect(result, [1, 2, 3]);
    });

    test("empty stream yields nothing", () async {
      const stream = Stream<List<int>>.empty();
      final result = await stream.flatten().toList();
      expect(result, isEmpty);
    });
  });

  group("ReplayableStream", () {
    test("replays buffered data to new listeners", () async {
      final source = Stream.fromIterable([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      final replayable = ReplayableStream(source);

      // Wait for buffer to be populated
      await Future.delayed(const Duration(milliseconds: 50));

      final result = await replayable.stream().expand((e) => e).toList();
      expect(result, [1, 2, 3, 4, 5, 6]);
    });

    test("multiple listeners receive same data", () async {
      final source = Stream.fromIterable([
        [1, 2],
        [3, 4],
      ]);
      final replayable = ReplayableStream(source);

      // Wait for buffer to be populated
      await Future.delayed(const Duration(milliseconds: 50));

      final result1 = await replayable.stream().expand((e) => e).toList();
      final result2 = await replayable.stream().expand((e) => e).toList();

      expect(result1, [1, 2, 3, 4]);
      expect(result2, [1, 2, 3, 4]);
    });

    test("empty source stream replays empty data", () async {
      const source = Stream<List<int>>.empty();
      final replayable = ReplayableStream(source);

      // Wait for stream to complete
      await Future.delayed(const Duration(milliseconds: 50));

      final result = await replayable.stream().expand((e) => e).toList();
      expect(result, isEmpty);
    });

    test("buffer accumulates data from source", () async {
      final source = Stream.fromIterable([
        [1, 2],
        [3, 4],
        [5, 6],
      ]);
      final replayable = ReplayableStream(source);

      // Wait for buffer to be populated
      await Future.delayed(const Duration(milliseconds: 50));

      expect(replayable.buffer, [1, 2, 3, 4, 5, 6]);
    });

    test("late listener receives buffered data plus new events", () async {
      final controller = StreamController<List<int>>();
      final replayable = ReplayableStream(controller.stream);

      // Add initial data
      controller.add([1, 2]);
      await Future.delayed(const Duration(milliseconds: 50));

      // Start listening (should get buffered [1, 2] first, then new events [3, 4])
      final resultFuture = replayable.stream().expand((e) => e).toList();

      // Add more data
      controller.add([3, 4]);
      await Future.delayed(const Duration(milliseconds: 50));

      // Close the stream
      await controller.close();

      final result = await resultFuture;
      // The buffer contains [1, 2], and stream() yields buffer first, then new events from broadcast stream
      // Since broadcast stream doesn't replay, we only get [1, 2] (buffer) + [3, 4] (new events)
      expect(result, [1, 2, 3, 4]);
    });

    test("handles single chunk stream", () async {
      final source = Stream.fromIterable([
        [1, 2, 3, 4, 5],
      ]);
      final replayable = ReplayableStream(source);

      await Future.delayed(const Duration(milliseconds: 50));

      final result = await replayable.stream().expand((e) => e).toList();
      expect(result, [1, 2, 3, 4, 5]);
    });

    test("maintains chunk structure in replay", () async {
      final source = Stream.fromIterable([
        [1, 2],
        [3, 4],
        [5, 6],
      ]);
      final replayable = ReplayableStream(source);

      await Future.delayed(const Duration(milliseconds: 50));

      final result = await replayable.stream().toList();
      // First element is the buffer, then the broadcast stream chunks
      expect(result[0], [1, 2, 3, 4, 5, 6]); // buffer
    });

    test("handles errors in source stream gracefully", () async {
      final controller = StreamController<List<int>>();
      final replayable = ReplayableStream(controller.stream);

      controller.add([1, 2]);
      controller.addError(Exception("test error"));
      await controller.close();

      await Future.delayed(const Duration(milliseconds: 50));

      // Should still be able to get buffered data
      final result = await replayable.stream().expand((e) => e).toList();
      expect(result, [1, 2]);
    });
  });
}
