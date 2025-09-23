extension Flatten<T> on Iterable<Iterable<T>> {
  Iterable<T> flatten() sync* {
    for (final items in this) {
      yield* items;
    }
  }
}
