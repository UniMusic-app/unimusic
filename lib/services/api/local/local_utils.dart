Iterable<T> pageItems<T>(List<T> items, {int? limit, int? startIndex}) {
  final start = startIndex ?? 0;
  if (start >= items.length) {
    return const [];
  }

  final end = limit == null
      ? items.length
      : (start + limit).clamp(0, items.length);
  return items.sublist(start, end);
}

String? fileExtensionFromPath(String? path) {
  if (path == null || path.isEmpty) return null;
  final lastSegment = path.split(RegExp(r"[\\/]")).last;
  final dotIndex = lastSegment.lastIndexOf(".");
  if (dotIndex <= 0 || dotIndex == lastSegment.length - 1) return null;
  return lastSegment.substring(dotIndex + 1).trim().toUpperCase();
}
