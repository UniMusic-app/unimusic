import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:just_audio/just_audio.dart";
import "package:mocktail/mocktail.dart";
import "package:provider/provider.dart";
import "package:unimusic/services/music_manager.dart";
import "package:unimusic/services/provider_registry.dart";
import "package:unimusic/services/music_providers/music_provider.dart";

class MockMusicManager extends Mock implements MusicManager {}

class MockProviderRegistry extends Mock implements ProviderRegistry {}

/// Creates a [MockProviderRegistry] with sensible defaults for smoke tests.
MockProviderRegistry createMockProviderRegistry() {
  final mock = MockProviderRegistry();
  when(() => mock.providers).thenReturn({});
  when(
    () => mock.getLibraryItems(itemType: any(named: "itemType")),
  ).thenAnswer((_) => const Stream<MusicItem>.empty());
  when(
    () => mock.getSearchResults(
      query: any(named: "query"),
      itemType: any(named: "itemType"),
    ),
  ).thenAnswer((_) => const Stream<MusicItem>.empty());
  return mock;
}

/// Creates a [MockMusicManager] with sensible defaults for smoke tests.
MockMusicManager createMockMusicManager() {
  final mock = MockMusicManager();
  when(() => mock.queue).thenReturn([]);
  when(() => mock.queuePosition).thenReturn(0);
  when(() => mock.duration).thenReturn(Duration.zero);
  when(() => mock.position).thenReturn(Duration.zero);
  when(() => mock.bufferedPosition).thenReturn(Duration.zero);
  when(() => mock.volume).thenReturn(1.0);
  when(() => mock.isShuffleEnabled).thenReturn(false);
  when(() => mock.loopMode).thenReturn(LoopMode.off);
  when(() => mock.currentItem).thenReturn(null);
  when(() => mock.isPlaying).thenReturn(false);
  when(() => mock.canPlay).thenReturn(false);
  when(() => mock.canSkipPrevious).thenReturn(false);
  when(() => mock.canSkipNext).thenReturn(false);
  return mock;
}

/// Wraps [child] in providers supplying both [ProviderRegistry] and [MusicManager].
Widget wrapWithProviders(
  Widget child, {
  MusicManager? musicManager,
  ProviderRegistry? providerRegistry,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProviderRegistry>.value(
        value: providerRegistry ?? createMockProviderRegistry(),
      ),
      ChangeNotifierProvider<MusicManager>.value(
        value: musicManager ?? createMockMusicManager(),
      ),
    ],
    child: child,
  );
}

/// Pumps [widget] wrapped with the providers needed by the app.
Future<void> pumpWithProviders(
  WidgetTester tester,
  Widget widget, {
  MusicManager? musicManager,
  ProviderRegistry? providerRegistry,
}) async {
  await tester.pumpWidget(
    wrapWithProviders(
      widget,
      musicManager: musicManager,
      providerRegistry: providerRegistry,
    ),
  );
}
