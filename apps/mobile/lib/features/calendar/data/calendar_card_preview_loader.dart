import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

class CalendarCardPreviewLoader {
  const CalendarCardPreviewLoader(this._bucket);

  final StorageFileApi _bucket;

  Future<Uint8List> download(String path, {TransformOptions? transform}) async {
    if (transform != null) {
      try {
        final bytes = await _bucket
            .download(path, transform: transform)
            .timeout(AppConfig.supabaseRpcTimeout);
        if (bytes.isNotEmpty) return bytes;
      } on StorageException catch (error) {
        final status = int.tryParse(error.statusCode ?? '');
        if (status != 400 && status != 404) {
          rethrow;
        }
      }
    }

    return _bucket.download(path).timeout(AppConfig.supabaseRpcTimeout);
  }
}
