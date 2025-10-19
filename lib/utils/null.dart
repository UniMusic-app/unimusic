extension Let<Type> on Type? {
  Return? let<Return>(Return Function(Type) f) => this != null ? f(this as Type) : null;
}
