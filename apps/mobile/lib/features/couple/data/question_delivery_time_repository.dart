import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'couple_failure.dart';
import 'question_delivery_time.dart';

final questionDeliveryTimeRepositoryProvider =
    Provider<QuestionDeliveryTimeRepository>((ref) {
      return const SupabaseQuestionDeliveryTimeRepository();
    });

abstract interface class QuestionDeliveryTimeRepository {
  Future<void> setInitial(QuestionDeliveryTime time);

  Future<void> scheduleUpdate(QuestionDeliveryTime time);
}

class SupabaseQuestionDeliveryTimeRepository
    implements QuestionDeliveryTimeRepository {
  const SupabaseQuestionDeliveryTimeRepository();

  @override
  Future<void> setInitial(QuestionDeliveryTime time) {
    return _run(functionName: 'set_initial_question_delivery_time', time: time);
  }

  @override
  Future<void> scheduleUpdate(QuestionDeliveryTime time) {
    return _run(
      functionName: 'schedule_question_delivery_time_update',
      time: time,
    );
  }

  Future<void> _run({
    required String functionName,
    required QuestionDeliveryTime time,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleRepositoryException(CoupleFailureReason.configMissing);
    }

    try {
      await Supabase.instance.client.rpc(
        functionName,
        params: {'requested_time': time.toDatabase()},
      );
    } on PostgrestException catch (error) {
      throw CoupleRepositoryException(
        _reasonFromMessage(error.message),
        error.message,
      );
    }
  }

  CoupleFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => CoupleFailureReason.authRequired,
      'active_couple_required' => CoupleFailureReason.activeCoupleRequired,
      'relationship_date_required' =>
        CoupleFailureReason.relationshipDateRequired,
      'initial_setup_owner_required' =>
        CoupleFailureReason.initialSetupOwnerRequired,
      'invalid_question_delivery_time' =>
        CoupleFailureReason.invalidQuestionDeliveryTime,
      'question_delivery_time_already_set' =>
        CoupleFailureReason.questionDeliveryTimeAlreadySet,
      'question_delivery_time_required' =>
        CoupleFailureReason.questionDeliveryTimeRequired,
      _ => CoupleFailureReason.unknown,
    };
  }
}
