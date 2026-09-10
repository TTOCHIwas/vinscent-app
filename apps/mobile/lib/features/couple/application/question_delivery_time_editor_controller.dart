import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/couple_failure.dart';
import '../data/question_delivery_time.dart';
import '../data/question_delivery_time_repository.dart';
import 'couple_controller.dart';
import 'question_delivery_time_editor_state.dart';

final questionDeliveryTimeEditorControllerProvider =
    AsyncNotifierProvider.autoDispose<
      QuestionDeliveryTimeEditorController,
      QuestionDeliveryTimeEditorState
    >(QuestionDeliveryTimeEditorController.new, retry: (_, _) => null);

class QuestionDeliveryTimeEditorController
    extends AsyncNotifier<QuestionDeliveryTimeEditorState> {
  @override
  Future<QuestionDeliveryTimeEditorState> build() async {
    final couple = await ref.read(coupleControllerProvider.future);
    final effectiveTime = couple?.questionDeliveryTime;
    if (couple == null || !couple.isActive || effectiveTime == null) {
      throw StateError('An active couple with a question time is required.');
    }

    final savedTime = couple.pendingQuestionDeliveryTime ?? effectiveTime;
    return QuestionDeliveryTimeEditorState(
      effectiveTime: effectiveTime,
      selectedTime: savedTime,
      pendingTime: couple.pendingQuestionDeliveryTime,
      pendingEffectiveDate: couple.pendingQuestionDeliveryTimeEffectiveDate,
    );
  }

  void selectTime(QuestionDeliveryTime value) {
    final current = state.asData?.value;
    if (current == null || current.isSaving) {
      return;
    }
    state = AsyncValue.data(
      current.copyWith(selectedTime: value, clearErrorMessage: true),
    );
  }

  Future<bool> save() async {
    final current = state.asData?.value;
    if (current == null || !current.canSave) {
      return false;
    }

    state = AsyncValue.data(
      current.copyWith(isSaving: true, clearErrorMessage: true),
    );
    try {
      await ref
          .read(questionDeliveryTimeRepositoryProvider)
          .scheduleUpdate(current.selectedTime);
      await ref.read(coupleControllerProvider.notifier).refreshSilently();
      if (ref.mounted) {
        final couple = ref.read(coupleControllerProvider).asData?.value;
        final effectiveTime = couple?.questionDeliveryTime;
        if (effectiveTime == null) {
          throw StateError('The refreshed question time is missing.');
        }
        final pendingTime = couple?.pendingQuestionDeliveryTime;
        state = AsyncValue.data(
          QuestionDeliveryTimeEditorState(
            effectiveTime: effectiveTime,
            selectedTime: pendingTime ?? effectiveTime,
            pendingTime: pendingTime,
            pendingEffectiveDate:
                couple?.pendingQuestionDeliveryTimeEffectiveDate,
          ),
        );
      }
      return true;
    } catch (error) {
      if (ref.mounted) {
        state = AsyncValue.data(
          current.copyWith(isSaving: false, errorMessage: _messageFor(error)),
        );
      }
      return false;
    }
  }

  String _messageFor(Object error) {
    if (error is CoupleRepositoryException) {
      return switch (error.reason) {
        CoupleFailureReason.invalidQuestionDeliveryTime =>
          '질문을 받을 시간을 다시 선택해 주세요.',
        CoupleFailureReason.activeCoupleRequired => '커플 연결 상태를 다시 확인해 주세요.',
        CoupleFailureReason.authRequired => '다시 로그인해 주세요.',
        _ => '질문 시간을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.',
      };
    }
    return '질문 시간을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.';
  }
}
