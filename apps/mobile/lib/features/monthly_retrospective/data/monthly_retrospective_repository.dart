import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/signed_url_cache.dart';
import 'monthly_retrospective.dart';

final monthlyRetrospectiveRepositoryProvider =
    Provider<MonthlyRetrospectiveRepository>(
      (ref) => SupabaseMonthlyRetrospectiveRepository(
        ref.watch(signedUrlCacheProvider),
      ),
    );

abstract interface class MonthlyRetrospectiveRepository {
  Future<MonthlyRetrospectiveAvailability> fetchAvailability();
  Future<MonthlyRetrospective> fetch();
  Future<void> generate();
  Future<MonthlyRetrospective> save(
    RetrospectiveReflection reflection,
    String text,
  );
  Future<MonthlyRetrospective> useBasicQuestion(String id);
  Future<Map<String, String>> previewUrls(Iterable<RetrospectiveCard> cards);
}

class SupabaseMonthlyRetrospectiveRepository
    implements MonthlyRetrospectiveRepository {
  const SupabaseMonthlyRetrospectiveRepository(this._cache);
  final SignedUrlCache _cache;
  SupabaseClient get _client {
    if (!AppConfig.isSupabaseConfigured) {
      throw StateError('Supabase 설정을 확인해 주세요');
    }
    return Supabase.instance.client;
  }

  Future<Map<String, dynamic>> _readRow(
    String name, [
    Map<String, Object?>? params,
  ]) async {
    final data = await _client
        .rpc(name, params: params)
        .timeout(AppConfig.supabaseRpcTimeout);
    if (data is! Map) {
      throw const FormatException('Invalid monthly retrospective');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<MonthlyRetrospective> _read(
    String name, [
    Map<String, Object?>? params,
  ]) async => MonthlyRetrospective.fromJson(await _readRow(name, params));

  @override
  Future<MonthlyRetrospectiveAvailability> fetchAvailability() async =>
      MonthlyRetrospectiveAvailability.fromJson(
        await _readRow('get_current_monthly_retrospective_availability'),
      );

  @override
  Future<MonthlyRetrospective> fetch() =>
      _read('get_current_monthly_retrospective');
  @override
  Future<void> generate() async {
    await _client.functions
        .invoke('generate-monthly-retrospective', body: <String, Object?>{})
        .timeout(const Duration(seconds: 65));
  }

  @override
  Future<MonthlyRetrospective> save(
    RetrospectiveReflection reflection,
    String text,
  ) => _read('submit_current_monthly_retrospective_answer', {
    'requested_retrospective_id': reflection.id,
    'requested_answer_text': text,
    'expected_version': reflection.version,
  });
  @override
  Future<MonthlyRetrospective> useBasicQuestion(String id) => _read(
    'use_basic_monthly_retrospective_question',
    {'requested_retrospective_id': id},
  );
  @override
  Future<Map<String, String>> previewUrls(Iterable<RetrospectiveCard> cards) =>
      _cache.resolve(
        bucketId: 'story-cards',
        paths: cards.map((c) => c.previewPath),
        expiresInSeconds: 3600,
        loader: (paths, expires) async {
          final urls = await _client.storage
              .from('story-cards')
              .createSignedUrls(paths, expires)
              .timeout(AppConfig.supabaseRpcTimeout);
          return {for (final url in urls) url.path: url.signedUrl};
        },
      );
}
