import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/home_widget_synchronizer.dart';

final homeWidgetAssetDownloaderProvider = Provider<HomeWidgetAssetDownloader>((
  ref,
) {
  return const HttpHomeWidgetAssetDownloader();
});

class HttpHomeWidgetAssetDownloader implements HomeWidgetAssetDownloader {
  const HttpHomeWidgetAssetDownloader();

  static const _requestTimeout = Duration(seconds: 15);

  @override
  Future<Uint8List> download(String url, {required int maxBytes}) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw const FormatException('Unsupported home widget asset URL');
    }

    final client = HttpClient()..connectionTimeout = _requestTimeout;
    try {
      final request = await client.getUrl(uri).timeout(_requestTimeout);
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Home widget asset request failed: ${response.statusCode}',
          uri: uri,
        );
      }
      if (response.contentLength > maxBytes) {
        throw const FileSystemException('Home widget asset is too large');
      }

      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(_requestTimeout)) {
        if (builder.length + chunk.length > maxBytes) {
          throw const FileSystemException('Home widget asset is too large');
        }
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }
}
