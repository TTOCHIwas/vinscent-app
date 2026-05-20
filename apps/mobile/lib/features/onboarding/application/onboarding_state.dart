import 'package:characters/characters.dart';

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

  String get trimmedNickname => nickname.trim();

  int get nicknameLength => trimmedNickname.characters.length;

  bool get isNicknameValid => nicknameLength >= 2 && nicknameLength <= 8;

  bool get isBirthDateValid {
    final selected = birthDate;
    if (selected == null) {
      return false;
    }

    return !_dateOnly(selected).isAfter(_dateOnly(DateTime.now()));
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

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
