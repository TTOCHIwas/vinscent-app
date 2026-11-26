import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vinscent/features/calendar/data/calendar_card_preview_loader.dart';

void main() {
  const path = 'couple/loops/2026-09-02/user/card/preview.png';
  const transform = TransformOptions(
    width: 154,
    height: 192,
    resize: ResizeMode.contain,
  );
  final optimizedBytes = Uint8List.fromList([1, 2]);
  final originalBytes = Uint8List.fromList([3, 4, 5, 6]);

  test('downloads only the requested private transform on success', () async {
    final storage = _Storage(originalBytes, optimizedBytes);
    final loader = CalendarCardPreviewLoader(storage);

    expect(await loader.download(path, transform: transform), optimizedBytes);
    expect(storage.requests, [(path, transform)]);
  });

  test('downloads the original when transformations are disabled', () async {
    final storage = _Storage(
      originalBytes,
      const StorageException('Transform disabled', statusCode: '404'),
    );
    final loader = CalendarCardPreviewLoader(storage);

    expect(await loader.download(path, transform: transform), originalBytes);
    expect(storage.requests, [(path, transform), (path, null)]);
  });

  test('propagates authorization errors without a second request', () async {
    const error = StorageException('Invalid JWT', statusCode: '401');
    final storage = _Storage(originalBytes, error);
    final loader = CalendarCardPreviewLoader(storage);

    await expectLater(
      loader.download(path, transform: transform),
      throwsA(error),
    );
    expect(storage.requests, [(path, transform)]);
  });

  test('uses the original directly when no smaller size is required', () async {
    final storage = _Storage(originalBytes, optimizedBytes);
    final loader = CalendarCardPreviewLoader(storage);

    expect(await loader.download(path), originalBytes);
    expect(storage.requests, [(path, null)]);
  });
}

class _Storage extends Fake implements StorageFileApi {
  _Storage(this.originalBytes, this.transformedResult);

  final Uint8List originalBytes;
  final Object transformedResult;
  final requests = <(String, TransformOptions?)>[];

  @override
  Future<Uint8List> download(
    String path, {
    TransformOptions? transform,
    Map<String, String>? queryParams,
  }) async {
    requests.add((path, transform));
    if (transform == null) return originalBytes;
    final result = transformedResult;
    if (result is StorageException) throw result;
    return result as Uint8List;
  }
}
