import "package:flutter_test/flutter_test.dart";
import "package:unimusic/utils/duration.dart";

void main() {
  group("FormatDuration.formatted", () {
    test("zero duration", () {
      expect(Duration.zero.formatted, "0:00");
    });

    test("seconds only", () {
      expect(const Duration(seconds: 5).formatted, "0:05");
      expect(const Duration(seconds: 30).formatted, "0:30");
      expect(const Duration(seconds: 59).formatted, "0:59");
    });

    test("minutes and seconds", () {
      expect(const Duration(minutes: 1).formatted, "1:00");
      expect(const Duration(minutes: 3, seconds: 45).formatted, "3:45");
      expect(const Duration(minutes: 10, seconds: 9).formatted, "10:09");
      expect(const Duration(minutes: 59, seconds: 59).formatted, "59:59");
    });

    test("hours, minutes, and seconds", () {
      expect(const Duration(hours: 1).formatted, "1:00:00");
      expect(
        const Duration(hours: 1, minutes: 2, seconds: 3).formatted,
        "1:02:03",
      );
      expect(
        const Duration(hours: 10, minutes: 30, seconds: 45).formatted,
        "10:30:45",
      );
      expect(
        const Duration(hours: 100, minutes: 0, seconds: 0).formatted,
        "100:00:00",
      );
    });

    test("negative duration", () {
      expect(const Duration(seconds: -5).formatted, "-0:05");
      expect(const Duration(minutes: -3, seconds: -45).formatted, "-3:45");
      expect(
        const Duration(hours: -1, minutes: -2, seconds: -3).formatted,
        "-1:02:03",
      );
    });

    test("pads seconds and minutes with leading zero", () {
      expect(const Duration(minutes: 1, seconds: 1).formatted, "1:01");
      expect(
        const Duration(hours: 1, minutes: 1, seconds: 1).formatted,
        "1:01:01",
      );
    });

    test("sub-second durations show as zero seconds", () {
      expect(const Duration(milliseconds: 500).formatted, "0:00");
      expect(const Duration(milliseconds: 999).formatted, "0:00");
    });
  });
}
