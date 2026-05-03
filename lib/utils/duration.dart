extension FormatDuration on Duration {
  String get formatted {
    String padNum(int num) => num.toString().padLeft(2, "0");

    final hours = inHours.abs();
    final minutes = (inMinutes.abs() % 60);
    final seconds = (inSeconds.abs() % 60);

    final formatted = hours > 0
        ? "$hours:${padNum(minutes)}:${padNum(seconds)}"
        : "$minutes:${padNum(seconds)}";

    return isNegative ? "-$formatted" : formatted;
  }
}
