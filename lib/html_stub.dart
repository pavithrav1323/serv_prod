// Minimal mobile stubs so code compiles & runs without dart:html.

class _StorageMap {
  final Map<String, String> _m = {};
  String? operator [](String key) => _m[key];
  void operator []=(String key, String value) => _m[key] = value;
  Iterable<String> get keys => _m.keys;
  int get length => _m.length;
  void clear() => _m.clear();
  String? putIfAbsent(String key, String Function() ifAbsent) =>
      _m.putIfAbsent(key, ifAbsent);

  void remove(String s) {}
}

class _Window {
  final localStorage = _StorageMap();
  final sessionStorage = _StorageMap();

  // No-op on mobile (web uses window.open)
  void open(String url, String target) {}
}

final window = _Window();

class Blob {
  final List<Object> data;
  final String? type;
  Blob(this.data, [this.type]);
}

class Url {
  static String createObjectUrlFromBlob(Blob _) => '';
  static void revokeObjectUrl(String _) {}
}

class AnchorElement {
  String? href;
  String? download;
  String? target; // added for your code (..target = '_blank')
  AnchorElement({this.href, this.download, this.target});
  void click() {}
}
