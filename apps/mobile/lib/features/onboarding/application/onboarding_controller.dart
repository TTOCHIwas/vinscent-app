import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_state.dart';

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
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
}
