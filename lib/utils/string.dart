extension StringUtils on String {
  String get capitalized {
    if (isEmpty) return "";
    return this[0].toUpperCase() + substring(1);
  }

  String get uncapitalized {
    if (isEmpty) return "";
    return this[0].toLowerCase() + substring(1);
  }

  int compareAlphabetically(String other) =>
      toLowerCase().compareTo(other.toLowerCase());
}
