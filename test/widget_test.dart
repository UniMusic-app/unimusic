import "package:flutter_test/flutter_test.dart";
import "package:unimusic/main.dart";

import "test_helpers.dart";

void main() {
  testWidgets("UniMusicApp renders without crashing", (tester) async {
    await pumpWithProviders(tester, const UniMusicApp());
    await tester.pumpAndSettle();

    expect(find.byType(UniMusicApp), findsOneWidget);
  });
}
