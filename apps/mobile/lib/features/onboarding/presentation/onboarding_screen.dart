import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/widgets/app_back_button.dart';
import '../../../core/theme/app_colors.dart';
import '../application/onboarding_controller.dart';
import '../application/onboarding_state.dart';
import 'widgets/birth_date_picker_sheet.dart';
import 'widgets/birth_date_step.dart';
import 'widgets/nickname_step.dart';
import 'widgets/onboarding_action_button.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 34),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: state.canGoBack
                      ? AppBackButton(
                          onPressed: controller.goBack,
                          iconSize: 20,
                          tooltip: '이전',
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: switch (state.step) {
                    OnboardingStep.nickname => NicknameStep(
                      key: const ValueKey(OnboardingStep.nickname),
                      nickname: state.nickname,
                      isValid: state.isNicknameValid,
                      onChanged: controller.updateNickname,
                      onClear: controller.clearNickname,
                    ),
                    OnboardingStep.birthDate => BirthDateStep(
                      key: const ValueKey(OnboardingStep.birthDate),
                      birthDate: state.birthDate,
                      onTap: () =>
                          _showBirthDatePicker(context, ref, state.birthDate),
                    ),
                  },
                ),
              ),
              if (state.errorMessage != null) ...[
                Text(
                  state.errorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              OnboardingActionButton(
                label: '완료',
                enabled: state.canContinue,
                isLoading: state.isSubmitting,
                onPressed: switch (state.step) {
                  OnboardingStep.nickname => controller.goToBirthDate,
                  OnboardingStep.birthDate => controller.completeOnboarding,
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBirthDatePicker(
    BuildContext context,
    WidgetRef ref,
    DateTime? selectedDate,
  ) async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final today = DateTime.now();
    final maxDate = DateTime(today.year, today.month, today.day);
    final initialDate = selectedDate ?? maxDate;
    final pickedDate = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BirthDatePickerSheet(initialDate: initialDate, maxDate: maxDate);
      },
    );

    if (pickedDate != null) {
      controller.updateBirthDate(pickedDate);
    }
  }
}
