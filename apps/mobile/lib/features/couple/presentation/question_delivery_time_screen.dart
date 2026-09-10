import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/widgets/app_action_button.dart';
import '../../../core/presentation/widgets/app_action_tone.dart';
import '../../../core/presentation/widgets/app_confirmation_dialog.dart';
import '../../../core/presentation/widgets/app_setup_page.dart';
import '../../../core/presentation/widgets/app_time_picker_sheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/couple_flow_controller.dart';
import '../application/couple_flow_state.dart';
import '../data/question_delivery_time.dart';
import 'widgets/question_delivery_time_field.dart';

class QuestionDeliveryTimeScreen extends ConsumerWidget {
  const QuestionDeliveryTimeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(coupleFlowControllerProvider);
    final controller = ref.read(coupleFlowControllerProvider.notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !state.isSubmitting) {
          _confirmCancellation(context, controller);
        }
      },
      child: AppSetupPage(
        header: AppSetupHeader(
          onBackPressed: state.isSubmitting
              ? null
              : () => _confirmCancellation(context, controller),
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
              label: '다음',
              enabled: state.canSaveQuestionTime,
              isLoading:
                  state.operation == CoupleFlowOperation.savingQuestionTime,
              tone: AppActionTone.brand,
              onPressed: controller.saveQuestionDeliveryTime,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('오늘 질문은 언제 받을까?', style: AppTextStyles.onboardingTitle),
            const SizedBox(height: 8),
            Text(
              '두 사람에게 매일 같은 시간에 질문을 보내줄게',
              style: AppTextStyles.homeBody.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 32),
            QuestionDeliveryTimeField(
              selectedTime: state.questionDeliveryTime,
              onTap: state.isSubmitting
                  ? null
                  : () => _pickTime(
                      context,
                      controller,
                      state.questionDeliveryTime,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancellation(
    BuildContext context,
    CoupleFlowController controller,
  ) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: '커플 연결 설정을 그만둘까?',
      message: '지금 나가면 방금 연결한 커플이 취소되고, 두 사람 모두 다시 연결할 수 있어',
      confirmLabel: '연결 취소',
    );
    if (confirmed) {
      await controller.cancelInitialSetup();
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    CoupleFlowController controller,
    QuestionDeliveryTime selectedTime,
  ) async {
    final pickedTime = await showAppTimePickerSheet(
      context: context,
      title: '질문 받을 시간',
      initialTime: TimeOfDay(
        hour: selectedTime.hour,
        minute: selectedTime.minute,
      ),
    );
    if (pickedTime != null) {
      controller.updateQuestionDeliveryTime(
        QuestionDeliveryTime(hour: pickedTime.hour, minute: pickedTime.minute),
      );
    }
  }
}
