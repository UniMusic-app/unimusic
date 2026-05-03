import "package:flutter_test/flutter_test.dart";
import "package:unimusic/utils/string.dart";

void main() {
  group("StringUtils.capitalized", () {
    test("empty string returns empty", () {
      expect("".capitalized, "");
    });

    test("single lowercase letter", () {
      expect("a".capitalized, "A");
    });

    test("single uppercase letter stays unchanged", () {
      expect("A".capitalized, "A");
    });

    test("capitalizes first letter of a word", () {
      expect("hello".capitalized, "Hello");
    });

    test("already capitalized stays unchanged", () {
      expect("Hello".capitalized, "Hello");
    });

    test("preserves rest of the string", () {
      expect("hELLO wORLD".capitalized, "HELLO wORLD");
    });

    test("works with non-letter first character", () {
      expect("123abc".capitalized, "123abc");
    });
  });

  group("StringUtils.uncapitalized", () {
    test("empty string returns empty", () {
      expect("".uncapitalized, "");
    });

    test("single uppercase letter", () {
      expect("A".uncapitalized, "a");
    });

    test("single lowercase letter stays unchanged", () {
      expect("a".uncapitalized, "a");
    });

    test("lowercases first letter of a word", () {
      expect("Hello".uncapitalized, "hello");
    });

    test("already uncapitalized stays unchanged", () {
      expect("hello".uncapitalized, "hello");
    });

    test("preserves rest of the string", () {
      expect("HELLO".uncapitalized, "hELLO");
    });
  });

  group("StringUtils.compareAlphabetically", () {
    test("equal strings return 0", () {
      expect("abc".compareAlphabetically("abc"), 0);
    });

    test("case-insensitive comparison", () {
      expect("ABC".compareAlphabetically("abc"), 0);
      expect("Hello".compareAlphabetically("hello"), 0);
    });

    test("returns negative when first is before second", () {
      expect("apple".compareAlphabetically("banana"), isNegative);
    });

    test("returns positive when first is after second", () {
      expect("banana".compareAlphabetically("apple"), isPositive);
    });

    test("works with mixed case", () {
      expect("Apple".compareAlphabetically("banana"), isNegative);
      expect("BANANA".compareAlphabetically("apple"), isPositive);
    });
  });
}
