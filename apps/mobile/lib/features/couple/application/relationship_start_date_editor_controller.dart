import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../data/couple_failure.dart';
import 'couple_controller.dart';
import 'relationship_start_date_editor_state.dart';

final relationshipStartDateEditorControllerProvider =
    AsyncNotifierProvider.autoDispose<
      RelationshipStartDateEditorController,
      RelationshipStartDateEditorState
    >(RelationshipStartDateEditorController.new, retry: (_, _) => null);

class RelationshipStartDateEditorController
    extends AsyncNotifier<RelationshipStartDateEditorState> {
  @override
  Future<RelationshipStartDateEditorState> build() async {
    final couple = await ref.read(coupleControllerProvider.future);
    final relationshipStartDate = couple?.relationshipStartDate;
    if (couple == null || !couple.isActive || relationshipStartDate == null) {
      throw StateError(
        'An active couple with a relationship date is required.',
      );
    }

    final originalDate = calendarDateOnly(relationshipStartDate);
    return RelationshipStartDateEditorState(
      originalDate: originalDate,
      selectedDate: originalDate,
      latestAllowedDate: calendarDateOnly(couple.effectiveCurrentDate),
    );
  }

  void selectDate(DateTime value) {
    final current = state.asData?.value;
    if (current == null || current.isSaving) {
      return;
    }

    final selectedDate = calendarDateOnly(value);
    if (selectedDate.isAfter(current.latestAllowedDate)) {
      return;
    }

    state = AsyncValue.data(
      current.copyWith(selectedDate: selectedDate, clearErrorMessage: true),
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
      final couple = await ref
          .read(coupleControllerProvider.notifier)
          .updateRelationshipStartDate(current.selectedDate);
      final savedDate = couple.relationshipStartDate;
      if (savedDate == null) {
        throw StateError('The saved relationship date is missing.');
      }
      if (ref.mounted) {
        final normalizedDate = calendarDateOnly(savedDate);
        state = AsyncValue.data(
          current.copyWith(
            originalDate: normalizedDate,
            selectedDate: normalizedDate,
            latestAllowedDate: calendarDateOnly(couple.effectiveCurrentDate),
            isSaving: false,
            clearErrorMessage: true,
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
    if (error is! CoupleRepositoryException) {
      return '만난 날을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.';
    }

    return switch (error.reason) {
      CoupleFailureReason.relationshipDateConflict =>
        '이미 기록이 있는 날짜보다 뒤로 옮길 수 없어요.',
      CoupleFailureReason.futureDate => '오늘 이후 날짜는 선택할 수 없어요.',
      CoupleFailureReason.activeCoupleRequired => '커플 연결 상태를 다시 확인해 주세요.',
      CoupleFailureReason.authRequired => '다시 로그인해 주세요.',
      _ => '만난 날을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.',
    };
  }
}
