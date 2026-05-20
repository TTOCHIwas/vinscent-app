import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../application/onboarding_controller.dart';
import '../application/onboarding_state.dart';
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
                      ? IconButton(
                          onPressed: controller.goBack,
                          icon: const Icon(Icons.arrow_back_ios_new),
                          color: AppColors.textPrimary,
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
                    OnboardingStep.birthDate => const _BirthDatePlaceholder(
                      key: ValueKey(OnboardingStep.birthDate),
                    ),
                  },
                ),
              ),
              OnboardingActionButton(
                label: '완료',
                enabled: state.canContinue,
                isLoading: state.isSubmitting,
                onPressed: state.step == OnboardingStep.nickname
                    ? controller.goToBirthDate
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirthDatePlaceholder extends StatelessWidget {
  const _BirthDatePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topLeft,
      child: Text('생일을 입력해 주세요.'),
    );
  }
}
