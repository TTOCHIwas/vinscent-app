import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/couple_controller.dart';
import '../application/couple_flow_controller.dart';
import '../application/couple_flow_state.dart';
import 'widgets/couple_action_button.dart';

class CoupleWaitingScreen extends ConsumerWidget {
  const CoupleWaitingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couple = ref
        .watch(coupleControllerProvider)
        .maybeWhen(data: (couple) => couple, orElse: () => null);
    final state = ref.watch(coupleFlowControllerProvider);
    final controller = ref.read(coupleFlowControllerProvider.notifier);
    final inviteCode = couple?.inviteCode ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text('상대방을 기다리고 있어요', style: AppTextStyles.onboardingTitle),
              const SizedBox(height: 12),
              Text(
                '아래 코드를 상대방에게 알려주세요. 상대방이 입력하면 자동으로 다음 단계로 이동해요.',
                style: AppTextStyles.homeBody.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 36),
              _InviteCodeBox(inviteCode: inviteCode),
              const SizedBox(height: 16),
              CoupleActionButton(
                label: '초대 코드 복사',
                enabled: inviteCode.isNotEmpty && !state.isSubmitting,
                isSecondary: true,
                onPressed: () => _copyInviteCode(context, inviteCode),
              ),
              const SizedBox(height: 12),
              CoupleActionButton(
                label: '연결 상태 새로고침',
                enabled: !state.isSubmitting,
                isSecondary: true,
                onPressed: () => ref.invalidate(coupleControllerProvider),
              ),
              const Spacer(),
              if (state.errorMessage != null) ...[
                Text(state.errorMessage!, style: AppTextStyles.compactError),
                const SizedBox(height: 12),
              ],
              CoupleActionButton(
                label: '초대 취소',
                enabled: !state.isSubmitting,
                isLoading: state.operation == CoupleFlowOperation.cancelling,
                isSecondary: true,
                onPressed: controller.cancelInvite,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyInviteCode(BuildContext context, String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('초대 코드를 복사했어요.')));
  }
}

class _InviteCodeBox extends StatelessWidget {
  const _InviteCodeBox({required this.inviteCode});

  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.wireframeBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        inviteCode.isEmpty ? '------' : inviteCode,
        textAlign: TextAlign.center,
        style: AppTextStyles.onboardingTitle.copyWith(
          fontSize: 32,
          letterSpacing: 4,
        ),
      ),
    );
  }
}
