import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/widgets/app_action_button.dart';
import '../../../core/presentation/widgets/app_action_tone.dart';
import '../../../core/presentation/widgets/app_date_picker_sheet.dart';
import '../../../core/presentation/widgets/app_setup_page.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/onboarding_controller.dart';
import '../application/onboarding_state.dart';
import 'widgets/birth_date_step.dart';
import 'widgets/nickname_step.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return AppSetupPage(
      header: AppSetupHeader(
        currentStep: state.step.index + 1,
        totalSteps: OnboardingStep.values.length,
        onBackPressed: state.canGoBack ? controller.goBack : null,
      ),
      bottomAction: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.errorMessage case final errorMessage?) ...[
            Text(errorMessage, style: AppTextStyles.compactError),
            const SizedBox(height: 10),
          ],
          AppActionButton(
            label: switch (state.step) {
              OnboardingStep.nickname => '다음',
              OnboardingStep.birthDate => '완료',
            },
            enabled: state.canContinue,
            isLoading: state.isSubmitting,
            tone: AppActionTone.brand,
            onPressed: switch (state.step) {
              OnboardingStep.nickname => controller.goToBirthDate,
              OnboardingStep.birthDate => controller.completeOnboarding,
            },
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: switch (state.step) {
          OnboardingStep.nickname => NicknameStep(
            key: const ValueKey(OnboardingStep.nickname),
            nickname: state.nickname,
            isValid: state.isNicknameValid,
            onChanged: controller.updateNickname,
            onClear: controller.clearNickname,
            onSubmitted: controller.goToBirthDate,
          ),
          OnboardingStep.birthDate => BirthDateStep(
            key: const ValueKey(OnboardingStep.birthDate),
            birthDate: state.birthDate,
            onTap: () => _showBirthDatePicker(context, ref, state.birthDate),
          ),
        },
      ),
    );
  }

  Future<void> _showBirthDatePicker(
    BuildContext context,
    WidgetRef ref,
    DateTime? selectedDate,
  ) async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final now = DateTime.now();
    final maxDate = DateTime(now.year, now.month, now.day);
    final pickedDate = await showAppDatePickerSheet(
      context: context,
      title: '생일 선택',
      initialDate: selectedDate ?? maxDate,
      minDate: DateTime(1900),
      maxDate: maxDate,
    );

    if (pickedDate != null) {
      controller.updateBirthDate(pickedDate);
    }
  }
}
