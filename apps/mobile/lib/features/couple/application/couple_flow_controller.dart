import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/couple_failure.dart';
import 'couple_controller.dart';
import 'couple_flow_state.dart';

final coupleFlowControllerProvider =
    NotifierProvider.autoDispose<CoupleFlowController, CoupleFlowState>(
      CoupleFlowController.new,
    );

class CoupleFlowController extends Notifier<CoupleFlowState> {
  @override
  CoupleFlowState build() {
    return const CoupleFlowState();
  }

  void updateInviteCode(String value) {
    state = state.copyWith(inviteCode: value, clearErrorMessage: true);
  }

  void updateRelationshipStartDate(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    if (date.isAfter(_today())) {
      return;
    }

    state = state.copyWith(
      relationshipStartDate: date,
      clearErrorMessage: true,
    );
  }

  Future<void> createInvite() async {
    if (state.isSubmitting) {
      return;
    }

    state = state.copyWith(
      operation: CoupleFlowOperation.creating,
      clearErrorMessage: true,
    );

    try {
      await ref.read(coupleControllerProvider.notifier).createInvite();
      state = state.copyWith(
        operation: CoupleFlowOperation.idle,
        clearErrorMessage: true,
      );
    } catch (error) {
      state = state.copyWith(
        operation: CoupleFlowOperation.idle,
        errorMessage: _messageFor(error),
      );
    }
  }

  Future<void> joinByCode() async {
    if (!state.canJoin) {
      return;
    }

    state = state.copyWith(
      operation: CoupleFlowOperation.joining,
      clearErrorMessage: true,
    );

    try {
      await ref
          .read(coupleControllerProvider.notifier)
          .joinByCode(state.normalizedInviteCode);
      state = state.copyWith(
        operation: CoupleFlowOperation.idle,
        clearErrorMessage: true,
      );
    } catch (error) {
      state = state.copyWith(
        operation: CoupleFlowOperation.idle,
        errorMessage: _messageFor(error),
      );
    }
  }

  Future<void> cancelInvite() async {
    if (state.isSubmitting) {
      return;
    }

    state = state.copyWith(
      operation: CoupleFlowOperation.cancelling,
      clearErrorMessage: true,
    );

    try {
      await ref.read(coupleControllerProvider.notifier).cancelInvite();
      state = state.copyWith(
        operation: CoupleFlowOperation.idle,
        clearErrorMessage: true,
      );
    } catch (error) {
      state = state.copyWith(
        operation: CoupleFlowOperation.idle,
        errorMessage: _messageFor(error),
      );
    }
  }

  Future<void> saveRelationshipStartDate() async {
    final date = state.relationshipStartDate;
    if (date == null || state.isSubmitting) {
      return;
    }

    state = state.copyWith(
      operation: CoupleFlowOperation.savingDate,
      clearErrorMessage: true,
    );

    try {
      await ref
          .read(coupleControllerProvider.notifier)
          .updateRelationshipStartDate(date);
      state = state.copyWith(
        operation: CoupleFlowOperation.idle,
        clearErrorMessage: true,
      );
    } catch (error) {
      state = state.copyWith(
        operation: CoupleFlowOperation.idle,
        errorMessage: _messageFor(error),
      );
    }
  }

  String _messageFor(Object error) {
    if (error is! CoupleRepositoryException) {
      return '잠시 후 다시 시도해주세요.';
    }

    return switch (error.reason) {
      CoupleFailureReason.authRequired => '다시 로그인해주세요.',
      CoupleFailureReason.profileRequired => '프로필 입력을 먼저 완료해주세요.',
      CoupleFailureReason.alreadyExists => '이미 연결 중인 커플이 있어요.',
      CoupleFailureReason.inviteNotFound => '초대 코드를 찾을 수 없어요.',
      CoupleFailureReason.inviteNotPending => '이미 사용된 초대 코드예요.',
      CoupleFailureReason.ownInvite => '내가 만든 초대 코드는 입력할 수 없어요.',
      CoupleFailureReason.invalidCode => '초대 코드 6자리를 확인해주세요.',
      CoupleFailureReason.futureDate => '오늘 이후 날짜는 선택할 수 없어요.',
      CoupleFailureReason.activeCoupleRequired => '커플 연결을 먼저 완료해주세요.',
      CoupleFailureReason.codeGenerationFailed => '초대 코드 생성에 실패했어요.',
      CoupleFailureReason.configMissing => '앱 설정이 아직 완료되지 않았어요.',
      CoupleFailureReason.unknown => '잠시 후 다시 시도해주세요.',
    };
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
