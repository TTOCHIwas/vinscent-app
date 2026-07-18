import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

final homeWidgetPartnerCardRepositoryProvider =
    Provider<HomeWidgetPartnerCardRepository>((ref) {
      return const SupabaseHomeWidgetPartnerCardRepository();
    });

abstract interface class HomeWidgetPartnerCardRepository {
  Future<HomeWidgetPartnerCard?> fetchLatestPartnerCard({
    required String coupleId,
    required String currentUserId,
  });
}

class HomeWidgetPartnerCard {
  const HomeWidgetPartnerCard({
    required this.id,
    required this.previewUrl,
    required this.revision,
    required this.updatedAt,
  });

  final String id;
  final String previewUrl;
  final int revision;
  final DateTime updatedAt;
}

class SupabaseHomeWidgetPartnerCardRepository
    implements HomeWidgetPartnerCardRepository {
  const SupabaseHomeWidgetPartnerCardRepository();

  static const _bucketId = 'story-cards';
  static const _signedUrlExpiresInSeconds = 60 * 60;

  @override
  Future<HomeWidgetPartnerCard?> fetchLatestPartnerCard({
    required String coupleId,
    required String currentUserId,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      return null;
    }

    final row = await Supabase.instance.client
        .from('story_loop_cards')
        .select('id, preview_path, revision, updated_at')
        .eq('couple_id', coupleId)
        .neq('author_user_id', currentUserId)
        .order('couple_date', ascending: false)
        .order('submitted_at', ascending: false)
        .limit(1)
        .maybeSingle()
        .timeout(AppConfig.supabaseRpcTimeout);
    if (row == null) {
      return null;
    }

    final previewUrl = await Supabase.instance.client.storage
        .from(_bucketId)
        .createSignedUrl(
          row['preview_path'] as String,
          _signedUrlExpiresInSeconds,
        )
        .timeout(AppConfig.supabaseRpcTimeout);

    return HomeWidgetPartnerCard(
      id: row['id'] as String,
      previewUrl: previewUrl,
      revision: (row['revision'] as num).toInt(),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
