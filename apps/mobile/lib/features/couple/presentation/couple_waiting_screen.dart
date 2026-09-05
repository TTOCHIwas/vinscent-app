import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/widgets/app_confirmation_dialog.dart';
import '../../../core/presentation/widgets/app_setup_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/couple_controller.dart';
import '../application/couple_flow_controller.dart';
import '../application/couple_flow_state.dart';

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

    return AppSetupPage(
      header: AppSetupHeader(
        action: IconButton(
          onPressed: state.isSubmitting
              ? null
              : () => ref.invalidate(coupleControllerProvider),
          icon: const Icon(Icons.refresh),
          color: AppColors.textPrimary,
          tooltip: '연결 상태 새로고침',
        ),
      ),
      bottomAction: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.errorMessage case final errorMessage?) ...[
            Text(errorMessage, style: AppTextStyles.compactError),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: state.isSubmitting
                  ? null
                  : () => _confirmCancellation(context, controller),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: state.operation == CoupleFlowOperation.cancelling
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  : const Text('초대 취소'),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('상대방을 기다리고 있어', style: AppTextStyles.onboardingTitle),
          const SizedBox(height: 8),
          Text(
            '아래 코드를 상대방에게 보내줘',
            style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 32),
          _InviteCodeSurface(
            inviteCode: inviteCode,
            onCopyPressed: inviteCode.isEmpty
                ? null
                : () => _copyInviteCode(context, inviteCode),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '연결을 기다리는 중',
                style: AppTextStyles.onboardingHint.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancellation(
    BuildContext context,
    CoupleFlowController controller,
  ) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: '초대를 취소할까?',
      message: '이 초대 코드는 더 이상 사용할 수 없어',
      confirmLabel: '초대 취소',
    );
    if (confirmed) {
      await controller.cancelInvite();
    }
  }

  Future<void> _copyInviteCode(BuildContext context, String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('초대 코드를 복사했어')));
  }
}

class _InviteCodeSurface extends StatelessWidget {
  const _InviteCodeSurface({
    required this.inviteCode,
    required this.onCopyPressed,
  });

  final String inviteCode;
  final VoidCallback? onCopyPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.formSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                inviteCode.isEmpty ? '------' : inviteCode,
                maxLines: 1,
                style: AppTextStyles.onboardingTitle.copyWith(
                  fontSize: 32,
                  letterSpacing: 5,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: onCopyPressed,
              icon: const Icon(Icons.copy_outlined),
              color: AppColors.textPrimary,
              tooltip: '초대 코드 복사',
            ),
          ),
        ],
      ),
    );
  }
}
