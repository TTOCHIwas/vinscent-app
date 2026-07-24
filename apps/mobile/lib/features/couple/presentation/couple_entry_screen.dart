import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/couple_flow_controller.dart';
import '../application/couple_flow_state.dart';
import 'widgets/couple_action_button.dart';

class CoupleEntryScreen extends ConsumerWidget {
  const CoupleEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(coupleFlowControllerProvider);
    final controller = ref.read(coupleFlowControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text('둘만의 공간을 만들어요', style: AppTextStyles.onboardingTitle),
              const SizedBox(height: 12),
              Text(
                '초대 코드를 만들거나 상대방의 코드를 입력하면 커플 공간이 연결돼요.',
                style: AppTextStyles.homeBody.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 36),
              CoupleActionButton(
                label: '내 초대 코드 만들기',
                enabled: !state.isSubmitting,
                isLoading: state.operation == CoupleFlowOperation.creating,
                onPressed: controller.createInvite,
              ),
              const SizedBox(height: 32),
              const _SectionDivider(label: '또는'),
              const SizedBox(height: 28),
              TextField(
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '초대 코드 6자리',
                  border: UnderlineInputBorder(),
                ),
                style: AppTextStyles.onboardingInput,
                onChanged: controller.updateInviteCode,
              ),
              const SizedBox(height: 16),
              CoupleActionButton(
                label: '상대 코드로 연결하기',
                enabled: state.canJoin,
                isLoading: state.operation == CoupleFlowOperation.joining,
                onPressed: controller.joinByCode,
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(state.errorMessage!, style: AppTextStyles.compactError),
              ],
              const Spacer(),
              Text(
                '연결 후 질문, 답변, 캐릭터, AI 기억은 모두 이 커플 공간에 저장돼요.',
                style: AppTextStyles.onboardingHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.wireframeBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.wireframeBorder)),
      ],
    );
  }
}
