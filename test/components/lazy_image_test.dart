import "dart:ui" as ui;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:unimusic/components/lazy_image.dart";
import "package:unimusic/services/api/local/shared/items.dart";
import "package:unimusic/services/database/cached_artwork.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

void main() {
  testWidgets(
    "renders synchronously available images without showing the placeholder",
    (tester) async {
      final testImage = await _createTestImage();
      addTearDown(testImage.dispose);

      await tester.pumpWidget(
        _buildLazyImage(
          artwork: TestArtwork(
            id: "artwork-1",
            providerId: "test",
            imageProvider: TestImageProvider(testImage),
          ),
        ),
      );

      expect(find.byKey(_placeholderIconKey), findsNothing);
      expect(find.byType(RawImage), findsOneWidget);
    },
  );

  testWidgets("clears the previous image when artwork becomes null", (
    tester,
  ) async {
    final testImage = await _createTestImage();
    addTearDown(testImage.dispose);

    await tester.pumpWidget(
      _buildLazyImage(
        artwork: TestArtwork(
          id: "artwork-1",
          providerId: "test",
          imageProvider: TestImageProvider(testImage),
        ),
      ),
    );

    expect(find.byType(RawImage), findsOneWidget);

    await tester.pumpWidget(_buildLazyImage(artwork: null));

    expect(find.byKey(_placeholderIconKey), findsOneWidget);
    expect(find.byType(RawImage), findsNothing);
  });

  test("CachedArtwork images reuse the same cache key", () {
    const artwork = TestCachedArtwork(id: "artwork-1", providerId: "test");

    final first = artwork.getImage(ArtworkSize.medium);
    final second = artwork.getImage(ArtworkSize.medium);
    final differentSize = artwork.getImage(ArtworkSize.small);

    expect(first, equals(second));
    expect(first?.hashCode, second?.hashCode);
    expect(first, isNot(equals(differentSize)));
  });

  test("LocalArtwork images reuse the same cache key", () {
    final artwork = LocalArtwork(id: "artwork-1");

    final first = artwork.getImage(ArtworkSize.medium);
    final second = artwork.getImage(ArtworkSize.medium);
    final differentSize = artwork.getImage(ArtworkSize.small);

    expect(first, equals(second));
    expect(first?.hashCode, second?.hashCode);
    expect(first, isNot(equals(differentSize)));
  });
}

const _placeholderIconKey = Key("lazy-image-placeholder");

Widget _buildLazyImage({required Artwork? artwork}) {
  return MaterialApp(
    home: Material(
      child: Center(
        child: LazyImage(
          artwork: artwork,
          size: ArtworkSize.medium,
          width: 48,
          height: 48,
          icon: const Icon(Icons.image_rounded, key: _placeholderIconKey),
        ),
      ),
    ),
  );
}

Future<ui.Image> _createTestImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint()..color = Colors.red);

  return recorder.endRecording().toImage(1, 1);
}

class TestArtwork extends Artwork {
  final ImageProvider? imageProvider;

  const TestArtwork({
    required super.id,
    required super.providerId,
    required this.imageProvider,
  });

  @override
  ImageProvider? getImage(ArtworkSize size) => imageProvider;

  @override
  Uri? getImageUri(ArtworkSize size) => null;
}

class TestCachedArtwork extends CachedArtwork {
  const TestCachedArtwork({required super.id, required super.providerId});

  @override
  String getMimeType() => "image/png";

  @override
  Uri? getImageUri(ArtworkSize size) =>
      Uri.parse("https://example.com/$providerId/$id/${size.name}.png");
}

class TestImageProvider extends ImageProvider<TestImageProvider> {
  final ui.Image image;

  const TestImageProvider(this.image);

  @override
  Future<TestImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    TestImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: image)),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestImageProvider && identical(other.image, image);

  @override
  int get hashCode => Object.hash(runtimeType, image);
}
