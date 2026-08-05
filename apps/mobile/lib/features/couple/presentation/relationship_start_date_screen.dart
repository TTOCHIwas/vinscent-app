import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/today_controller.dart';
import '../../../core/presentation/widgets/app_action_button.dart';
import '../../../core/presentation/widgets/app_action_tone.dart';
import '../../../core/presentation/widgets/app_confirmation_sheet.dart';
import '../../../core/presentation/widgets/app_date_picker_sheet.dart';
import '../../../core/presentation/widgets/app_setup_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/couple_flow_controller.dart';
import '../application/couple_flow_state.dart';
import 'widgets/relationship_start_date_field.dart';

class RelationshipStartDateScreen extends ConsumerWidget {
  const RelationshipStartDateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(coupleFlowControllerProvider);
    final controller = ref.read(coupleFlowControllerProvider.notifier);
    final selectedDate = state.relationshipStartDate;
    final today = ref.watch(todayControllerProvider);

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
              enabled: state.canSaveDate,
              isLoading: state.operation == CoupleFlowOperation.savingDate,
              tone: AppActionTone.brand,
              onPressed: controller.saveRelationshipStartDate,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('우리가 처음 만난 날은?', style: AppTextStyles.onboardingTitle),
            const SizedBox(height: 8),
            Text(
              '디데이와 둘만의 기념일을 계산하는 기준이야',
              style: AppTextStyles.homeBody.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 32),
            RelationshipStartDateField(
              selectedDate: selectedDate,
              onTap: state.isSubmitting
                  ? null
                  : () => _pickDate(
                      context,
                      controller,
                      selectedDate: selectedDate,
                      today: today,
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
    final confirmed = await showAppConfirmationSheet(
      context: context,
      title: '커플 연결 설정을 그만둘까?',
      message: '지금 나가면 방금 연결한 커플이 취소되고, 두 사람 모두 다시 연결할 수 있어',
      confirmLabel: '연결 취소',
    );
    if (confirmed) {
      await controller.cancelInitialSetup();
    }
  }

  Future<void> _pickDate(
    BuildContext context,
    CoupleFlowController controller, {
    required DateTime? selectedDate,
    required DateTime today,
  }) async {
    final pickedDate = await showAppDatePickerSheet(
      context: context,
      title: '만난 날 선택',
      initialDate: selectedDate ?? today,
      minDate: DateTime(1900),
      maxDate: today,
    );

    if (pickedDate != null) {
      controller.updateRelationshipStartDate(pickedDate);
    }
  }
}
