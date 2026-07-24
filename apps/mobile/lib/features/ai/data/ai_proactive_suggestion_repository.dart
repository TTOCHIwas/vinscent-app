import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../application/ai_current_location_service.dart';
import 'ai_proactive_suggestion.dart';

final aiProactiveSuggestionRepositoryProvider =
    Provider<AiProactiveSuggestionRepository>(
      (ref) => const SupabaseAiProactiveSuggestionRepository(),
    );

abstract interface class AiProactiveSuggestionRepository {
  Future<AiProactiveSuggestion> generate({
    required AiCurrentLocation? location,
  });

  Future<bool> claimImpression({
    required String contextDate,
    required String sessionId,
  });
}

class SupabaseAiProactiveSuggestionRepository
    implements AiProactiveSuggestionRepository {
  const SupabaseAiProactiveSuggestionRepository();

  static const requestTimeout = Duration(seconds: 45);

  @override
  Future<AiProactiveSuggestion> generate({
    required AiCurrentLocation? location,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const AiProactiveSuggestionException();
    }

    try {
      final response = await Supabase.instance.client.functions
          .invoke(
            'generate-ai-proactive-suggestion',
            body: location == null
                ? const <String, Object?>{}
                : {
                    'latitude': location.latitude,
                    'longitude': location.longitude,
                  },
          )
          .timeout(requestTimeout);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AiProactiveSuggestion.fromJson(data);
      }
      if (data is Map) {
        return AiProactiveSuggestion.fromJson(Map<String, dynamic>.from(data));
      }
      throw const FormatException('Invalid proactive suggestion');
    } on TimeoutException {
      throw const AiProactiveSuggestionException();
    } on FunctionException {
      throw const AiProactiveSuggestionException();
    } on FormatException {
      throw const AiProactiveSuggestionException();
    }
  }

  @override
  Future<bool> claimImpression({
    required String contextDate,
    required String sessionId,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const AiProactiveSuggestionException();
    }

    try {
      final data = await Supabase.instance.client
          .rpc(
            'claim_my_ai_proactive_suggestion_impression',
            params: {
              'requested_context_date': contextDate,
              'requested_session_id': sessionId,
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      if (data is bool) {
        return data;
      }
      throw const FormatException('Invalid proactive impression claim');
    } on TimeoutException {
      throw const AiProactiveSuggestionException();
    } on PostgrestException {
      throw const AiProactiveSuggestionException();
    } on FormatException {
      throw const AiProactiveSuggestionException();
    }
  }
}

class AiProactiveSuggestionException implements Exception {
  const AiProactiveSuggestionException();
}
