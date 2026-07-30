import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/date/app_date_policy.dart';
import 'package:vinscent/core/date/today_controller.dart';
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
    final container = ProviderContainer(
      overrides: [
        todayControllerProvider.overrideWithBuild(
          (ref, notifier) => DateTime(2020),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(onboardingControllerProvider.notifier);
    final validDate = DateTime(2000);
    final futureDate = DateTime(2020, 1, 2);

    controller.updateBirthDate(futureDate);
    expect(container.read(onboardingControllerProvider).birthDate, isNull);

    controller.updateBirthDate(validDate);
    expect(container.read(onboardingControllerProvider).birthDate, validDate);
  });

  test('keeps an underage birth date selected but disables completion', () {
    final today = currentAppDate();
    final container = ProviderContainer(
      overrides: [
        todayControllerProvider.overrideWithBuild((ref, notifier) => today),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(onboardingControllerProvider.notifier);

    controller.updateNickname('또치');
    controller.goToBirthDate();
    final underageBirthDate = DateTime(today.year - 13, today.month, today.day);
    controller.updateBirthDate(underageBirthDate);

    final state = container.read(onboardingControllerProvider);
    expect(state.birthDate, underageBirthDate);
    expect(state.canContinue, isFalse);
  });
}
