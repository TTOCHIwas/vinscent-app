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

  test('rejects birth dates after today', () {
    final today = DateTime.now();
    final pastDate = DateTime(today.year - 1, today.month, today.day);
    final futureDate = today.add(const Duration(days: 1));

    expect(OnboardingState(birthDate: pastDate).isBirthDateValid, isTrue);
    expect(OnboardingState(birthDate: futureDate).isBirthDateValid, isFalse);
  });
}
