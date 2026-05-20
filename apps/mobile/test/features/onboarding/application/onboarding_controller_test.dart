import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/onboarding/application/onboarding_controller.dart';
import 'package:vinscent/features/onboarding/application/onboarding_state.dart';

void main() {
  test(
    'moves from nickname step to birth date step only when nickname is valid',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(onboardingControllerProvider.notifier);

      controller.updateNickname('a');
      controller.goToBirthDate();

      expect(
        container.read(onboardingControllerProvider).step,
        OnboardingStep.nickname,
      );

      controller.updateNickname('연인');
      controller.goToBirthDate();

      expect(
        container.read(onboardingControllerProvider).step,
        OnboardingStep.birthDate,
      );
    },
  );

  test('ignores future birth dates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(onboardingControllerProvider.notifier);
    final today = DateTime.now();
    final validDate = DateTime(today.year - 20, today.month, today.day);
    final futureDate = today.add(const Duration(days: 1));

    controller.updateBirthDate(futureDate);
    expect(container.read(onboardingControllerProvider).birthDate, isNull);

    controller.updateBirthDate(validDate);
    expect(container.read(onboardingControllerProvider).birthDate, validDate);
  });
}
