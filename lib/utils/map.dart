extension RemoveNullEntries on Map<dynamic, dynamic> {
  void get removeNullEntries => removeWhere((_, value) => value == null);
}
