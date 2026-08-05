import '../../../core/date/app_age_policy.dart';
import '../../../core/date/app_date_policy.dart';
import '../../profile/application/profile_display_name_policy.dart';

enum OnboardingStep { nickname, birthDate }

class OnboardingState {
  const OnboardingState({
    this.step = OnboardingStep.nickname,
    this.nickname = '',
    this.birthDate,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final OnboardingStep step;
  final String nickname;
  final DateTime? birthDate;
  final bool isSubmitting;
  final String? errorMessage;

  String get trimmedNickname => normalizeProfileDisplayName(nickname);

  int get nicknameLength => profileDisplayNameLength(nickname);

  bool get isNicknameValid => isValidProfileDisplayName(nickname);

  bool get isBirthDateValid => isBirthDateValidOn(currentAppDate());

  bool isBirthDateValidOn(DateTime onDate) {
    final selected = birthDate;
    if (selected == null) {
      return false;
    }

    return meetsMinimumServiceAge(birthDate: selected, onDate: onDate);
  }

  bool get canGoBack => step != OnboardingStep.nickname && !isSubmitting;

  bool get canContinue {
    return switch (step) {
      OnboardingStep.nickname => isNicknameValid,
      OnboardingStep.birthDate => isBirthDateValid && !isSubmitting,
    };
  }

  OnboardingState copyWith({
    OnboardingStep? step,
    String? nickname,
    DateTime? birthDate,
    bool? isSubmitting,
    String? errorMessage,
    bool clearBirthDate = false,
    bool clearErrorMessage = false,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      nickname: nickname ?? this.nickname,
      birthDate: clearBirthDate ? null : birthDate ?? this.birthDate,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
