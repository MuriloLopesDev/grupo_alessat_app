import 'dart:collection';

class CacheService {
  final _cache = HashMap<String, dynamic>();

  dynamic get(String key) {
    return _cache[key];
  }

  void set(String key, dynamic value) {
    _cache[key] = value;
  }

  void remove(String key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }
}
