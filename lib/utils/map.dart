extension RemoveNullEntries on Map<dynamic, dynamic> {
  get removeNullEntries => removeWhere((_, value) => value == null);
}
