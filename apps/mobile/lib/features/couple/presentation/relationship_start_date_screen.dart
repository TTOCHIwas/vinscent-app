import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/assets/app_icons.dart';
import '../../../core/date/today_controller.dart';
import '../../../core/presentation/widgets/app_svg_icon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/couple_flow_controller.dart';
import '../application/couple_flow_state.dart';
import 'widgets/couple_action_button.dart';

class RelationshipStartDateScreen extends ConsumerWidget {
  const RelationshipStartDateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(coupleFlowControllerProvider);
    final controller = ref.read(coupleFlowControllerProvider.notifier);
    final selectedDate = state.relationshipStartDate;
    final today = ref.watch(todayControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text('첫 만남일을 알려주세요', style: AppTextStyles.onboardingTitle),
              const SizedBox(height: 12),
              Text(
                '둘만의 디데이와 기록은 이 날짜를 기준으로 보여줄게요.',
                style: AppTextStyles.homeBody.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 36),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      _pickDate(context, controller, selectedDate, today),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.wireframeBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const AppSvgIcon(
                          AppIcons.calendar,
                          color: AppColors.wireframeIcon,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          selectedDate == null
                              ? '날짜 선택'
                              : _formatDate(selectedDate),
                          style: selectedDate == null
                              ? AppTextStyles.onboardingHint
                              : AppTextStyles.homeBodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(state.errorMessage!, style: AppTextStyles.compactError),
              ],
              const Spacer(),
              CoupleActionButton(
                label: '완료',
                enabled: state.canSaveDate,
                isLoading: state.operation == CoupleFlowOperation.savingDate,
                onPressed: controller.saveRelationshipStartDate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    CoupleFlowController controller,
    DateTime? selectedDate,
    DateTime today,
  ) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? today,
      firstDate: DateTime(1900),
      lastDate: today,
    );

    if (pickedDate != null) {
      controller.updateRelationshipStartDate(pickedDate);
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }
}
