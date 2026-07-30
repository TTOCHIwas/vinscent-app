import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/onboarding/application/onboarding_state.dart';

void main() {
  test('validates nickname by trimmed visible character count', () {
    expect(const OnboardingState(nickname: 'a').isNicknameValid, isFalse);
    expect(const OnboardingState(nickname: ' ab ').isNicknameValid, isTrue);
    expect(const OnboardingState(nickname: '12345678').isNicknameValid, isTrue);
    expect(
      const OnboardingState(nickname: '123456789').isNicknameValid,
      isFalse,
    );
  });

  test('requires the minimum service age on the requested date', () {
    final onDate = DateTime(2026, 7, 30);

    expect(
      OnboardingState(
        birthDate: DateTime(2012, 7, 30),
      ).isBirthDateValidOn(onDate),
      isTrue,
    );
    expect(
      OnboardingState(
        birthDate: DateTime(2012, 7, 31),
      ).isBirthDateValidOn(onDate),
      isFalse,
    );
    expect(
      OnboardingState(
        birthDate: DateTime(2026, 7, 31),
      ).isBirthDateValidOn(onDate),
      isFalse,
    );
  });
}
