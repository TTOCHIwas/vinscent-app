import 'dart:typed_data';

class ImageBytesCache {
  ImageBytesCache({
    this.maximumBytes = 32 * 1024 * 1024,
    this.maximumEntryBytes = 6 * 1024 * 1024,
    this.lifetime = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static final shared = ImageBytesCache();

  final int maximumBytes;
  final int maximumEntryBytes;
  final Duration lifetime;
  final DateTime Function() _clock;
  final _entries = <String, _Entry>{};
  final _pending = <String, Future<Uint8List>>{};
  var _bytes = 0;
  var _generation = 0;

  Future<Uint8List> resolve(String url, Future<Uint8List> Function() load) {
    final now = _clock();
    _entries.removeWhere((key, entry) {
      if (entry.expiresAt.isAfter(now)) return false;
      _bytes -= entry.bytes.lengthInBytes;
      return true;
    });
    final cached = _entries.remove(url);
    if (cached != null) {
      _entries[url] = cached;
      return Future.value(cached.bytes);
    }
    final pending = _pending[url];
    if (pending != null) return pending;

    final generation = _generation;
    late final Future<Uint8List> request;
    request = Future.sync(load)
        .then((bytes) {
          final size = bytes.lengthInBytes;
          if (generation == _generation &&
              size > 0 &&
              size <= maximumEntryBytes &&
              size <= maximumBytes) {
            while (_bytes + size > maximumBytes && _entries.isNotEmpty) {
              _bytes -= _entries
                  .remove(_entries.keys.first)!
                  .bytes
                  .lengthInBytes;
            }
            _entries[url] = _Entry(bytes, _clock().add(lifetime));
            _bytes += size;
          }
          return bytes;
        })
        .whenComplete(() {
          if (identical(_pending[url], request)) _pending.remove(url);
        });
    _pending[url] = request;
    return request;
  }

  void clear() {
    _generation++;
    _entries.clear();
    _pending.clear();
    _bytes = 0;
  }

  void evict(String url) {
    final entry = _entries.remove(url);
    if (entry != null) _bytes -= entry.bytes.lengthInBytes;
  }
}

class _Entry {
  const _Entry(this.bytes, this.expiresAt);
  final Uint8List bytes;
  final DateTime expiresAt;
}
