import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_controller.dart';
import 'onboarding_state.dart';

final onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    return const OnboardingState();
  }

  void updateNickname(String value) {
    state = state.copyWith(nickname: value, clearErrorMessage: true);
  }

  void clearNickname() {
    state = state.copyWith(nickname: '', clearErrorMessage: true);
  }

  void goToBirthDate() {
    if (!state.isNicknameValid) {
      return;
    }

    state = state.copyWith(
      step: OnboardingStep.birthDate,
      clearErrorMessage: true,
    );
  }

  void goBack() {
    if (!state.canGoBack) {
      return;
    }

    state = state.copyWith(
      step: OnboardingStep.nickname,
      clearErrorMessage: true,
    );
  }

  void updateBirthDate(DateTime value) {
    final birthDate = DateTime(value.year, value.month, value.day);
    final today = DateTime.now();
    final maxDate = DateTime(today.year, today.month, today.day);
    if (birthDate.isAfter(maxDate)) {
      return;
    }

    state = state.copyWith(birthDate: birthDate, clearErrorMessage: true);
  }

  Future<void> completeOnboarding() async {
    final birthDate = state.birthDate;
    if (!state.isNicknameValid ||
        !state.isBirthDateValid ||
        birthDate == null ||
        state.isSubmitting) {
      return;
    }

    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);

    try {
      await ref
          .read(profileControllerProvider.notifier)
          .completeOnboarding(
            displayName: state.trimmedNickname,
            birthDate: birthDate,
          );

      state = state.copyWith(isSubmitting: false, clearErrorMessage: true);
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: '프로필 저장에 실패했습니다.',
      );
    }
  }
}
