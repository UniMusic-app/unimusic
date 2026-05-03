extension Let<T> on T? {
  Return? let<Return>(Return Function(T) f) =>
      this != null ? f(this as T) : null;
}
