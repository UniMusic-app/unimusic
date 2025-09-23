extension Capitalize on String {
  String get capitalized {
    if (length > 0) {
      return this[0].toUpperCase() + substring(1);
    }
    return "";
  }
}

extension Uncapitalize on String {
  String get uncapitalized {
    if (length > 0) {
      return this[0].toLowerCase() + substring(1);
    }
    return "";
  }
}

extension CompareAlphabetically on String {
  int compareAlphabetically(String other) =>
      toLowerCase().compareTo(other.toLowerCase());
}
