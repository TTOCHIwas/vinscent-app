import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../storage/image_bytes_cache.dart';

@immutable
class AppNetworkImage extends ImageProvider<AppNetworkImage> {
  const AppNetworkImage(this.url);

  final String url;
  static final _client = HttpClient()..autoUncompress = false;

  @override
  Future<AppNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    AppNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await ImageBytesCache.shared.resolve(url, () async {
      var client = _client;
      assert(() {
        client = debugNetworkImageHttpClientProvider?.call() ?? client;
        return true;
      }());
      final uri = Uri.base.resolve(url);
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw NetworkImageLoadException(
          statusCode: response.statusCode,
          uri: uri,
        );
      }
      final bytes = await consolidateHttpClientResponseBytes(response);
      if (bytes.isEmpty) throw StateError('Empty image response');
      return bytes;
    });
    try {
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      ImageBytesCache.shared.evict(url);
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AppNetworkImage && other.url == url;

  @override
  int get hashCode => Object.hash(AppNetworkImage, url);
}
