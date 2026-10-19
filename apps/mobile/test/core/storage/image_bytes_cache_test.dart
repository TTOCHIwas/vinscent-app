import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/storage/image_bytes_cache.dart';

void main() {
  test('shares in-flight bytes and reuses the completed download', () async {
    final cache = ImageBytesCache();
    final gate = Completer<Uint8List>();
    var calls = 0;
    Future<Uint8List> load() {
      calls++;
      return gate.future;
    }

    final first = cache.resolve('url', load);
    final second = cache.resolve('url', load);
    gate.complete(Uint8List.fromList([1, 2]));
    expect(await first, [1, 2]);
    expect(await second, [1, 2]);
    expect(await cache.resolve('url', load), [1, 2]);
    expect(calls, 1);
  });

  test('retries failures instead of retaining a failed future', () async {
    final cache = ImageBytesCache();
    await expectLater(
      cache.resolve('url', () async => throw StateError('failed')),
      throwsStateError,
    );
    expect(await cache.resolve('url', () async => Uint8List(1)), [0]);
  });

  test('expires bytes and treats a renewed URL as a different asset', () async {
    var now = DateTime(2026);
    final cache = ImageBytesCache(clock: () => now);
    var calls = 0;
    Future<Uint8List> load() async {
      calls++;
      return Uint8List(1);
    }

    await cache.resolve('url?token=one', load);
    await cache.resolve('url?token=two', load);
    now = now.add(const Duration(minutes: 6));
    await cache.resolve('url?token=one', load);
    expect(calls, 3);
  });

  test('evicts least recently used entries within the byte budget', () async {
    final cache = ImageBytesCache(maximumBytes: 4, maximumEntryBytes: 2);
    final calls = <String>[];
    Future<void> read(String key) async {
      await cache.resolve(key, () async {
        calls.add(key);
        return Uint8List(2);
      });
    }

    await read('a');
    await read('b');
    await read('a');
    await read('c');
    await read('a');
    await read('b');
    expect(calls, ['a', 'b', 'c', 'b']);
  });

  test('does not retain oversized entries', () async {
    final cache = ImageBytesCache(maximumEntryBytes: 1);
    var calls = 0;
    Future<Uint8List> load() async {
      calls++;
      return Uint8List(2);
    }

    await cache.resolve('url', load);
    await cache.resolve('url', load);
    expect(calls, 2);
  });

  test('clear prevents an old download from repopulating the cache', () async {
    final cache = ImageBytesCache();
    final old = Completer<Uint8List>();
    final request = cache.resolve('url', () => old.future);
    cache.clear();
    await cache.resolve('url', () async => Uint8List.fromList([2]));
    old.complete(Uint8List.fromList([1]));
    await request;
    expect(await cache.resolve('url', () async => throw StateError('cached')), [
      2,
    ]);
  });
}
