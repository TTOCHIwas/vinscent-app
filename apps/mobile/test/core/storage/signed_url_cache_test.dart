import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/storage/signed_url_cache.dart';

void main() {
  test('reuses a signed URL until its refresh window', () async {
    var now = DateTime.utc(2026, 9, 5, 12);
    var loadCount = 0;
    final cache = SignedUrlCache(clock: () => now);

    Future<Map<String, String>> load(
      List<String> paths,
      int expiresInSeconds,
    ) async {
      loadCount += 1;
      return {for (final path in paths) path: 'signed-$loadCount-$path'};
    }

    final first = await cache.resolve(
      bucketId: 'artworks',
      paths: const ['preview.webp'],
      expiresInSeconds: 3600,
      loader: load,
    );
    now = now.add(const Duration(minutes: 30));
    final second = await cache.resolve(
      bucketId: 'artworks',
      paths: const ['preview.webp'],
      expiresInSeconds: 3600,
      loader: load,
    );

    expect(loadCount, 1);
    expect(second, first);
  });

  test('refreshes a signed URL before it expires', () async {
    var now = DateTime.utc(2026, 9, 5, 12);
    var loadCount = 0;
    final cache = SignedUrlCache(clock: () => now);

    Future<Map<String, String>> load(
      List<String> paths,
      int expiresInSeconds,
    ) async {
      loadCount += 1;
      return {for (final path in paths) path: 'signed-$loadCount-$path'};
    }

    await cache.resolve(
      bucketId: 'artworks',
      paths: const ['preview.webp'],
      expiresInSeconds: 3600,
      loader: load,
    );
    now = now.add(const Duration(minutes: 56));
    final refreshed = await cache.resolve(
      bucketId: 'artworks',
      paths: const ['preview.webp'],
      expiresInSeconds: 3600,
      loader: load,
    );

    expect(loadCount, 2);
    expect(refreshed['preview.webp'], 'signed-2-preview.webp');
  });

  test('shares an in-flight signing request for the same path', () async {
    final completer = Completer<Map<String, String>>();
    var loadCount = 0;
    final cache = SignedUrlCache();

    Future<Map<String, String>> load(List<String> paths, int expiresInSeconds) {
      loadCount += 1;
      return completer.future;
    }

    final first = cache.resolve(
      bucketId: 'artworks',
      paths: const ['preview.webp'],
      expiresInSeconds: 3600,
      loader: load,
    );
    final second = cache.resolve(
      bucketId: 'artworks',
      paths: const ['preview.webp'],
      expiresInSeconds: 3600,
      loader: load,
    );
    await Future<void>.delayed(Duration.zero);

    expect(loadCount, 1);
    completer.complete(const {'preview.webp': 'signed-preview.webp'});
    expect(await first, await second);
  });
}
