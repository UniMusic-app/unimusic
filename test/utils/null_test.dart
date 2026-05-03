import "package:flutter_test/flutter_test.dart";
import "package:unimusic/utils/null.dart";

void main() {
  group("Let extension", () {
    test("applies function to non-null value", () {
      const int value = 42;
      final result = value.let((v) => v * 2);
      expect(result, 84);
    });

    test("returns null for null value", () {
      const int? value = null;
      final int? result = value.let((v) => v * 2);
      expect(result, isNull);
    });

    test("transforms type", () {
      const int value = 42;
      final String? result = value.let((v) => v.toString());
      expect(result, "42");
    });

    test("returns null transform result for null input", () {
      const String? value = null;
      final int? result = value.let((v) => v.length);
      expect(result, isNull);
    });

    test("works with non-null string", () {
      const String value = "hello";
      final result = value.let((v) => v.toUpperCase());
      expect(result, "HELLO");
    });
  });
}
