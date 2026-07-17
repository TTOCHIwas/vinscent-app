import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/app_action_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import 'widgets/settings_page_layout.dart';

class CoupleSettingsScreen extends ConsumerStatefulWidget {
  const CoupleSettingsScreen({super.key});

  @override
  ConsumerState<CoupleSettingsScreen> createState() =>
      _CoupleSettingsScreenState();
}

class _CoupleSettingsScreenState extends ConsumerState<CoupleSettingsScreen> {
  var _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final couple = ref.watch(coupleControllerProvider);

    return SettingsPageLayout(
      title: '커플 설정',
      onBackPressed: () => context.pop(),
      child: couple.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (error, stackTrace) => const _CoupleSettingsMessage(
          title: '커플 정보를 불러오지 못했어요.',
          message: '잠시 후 다시 시도해 주세요.',
        ),
        data: (couple) {
          if (couple == null) {
            return const _CoupleSettingsMessage(
              title: '연결된 커플이 없어요.',
              message: '커플 연결을 먼저 완료해 주세요.',
            );
          }

          if (couple.isArchivedReadOnly) {
            return _ArchivedCoupleSettingsContent(
              couple: couple,
              isProcessing: _isProcessing,
              onReconnectPressed: _reconnectCouple,
              onDeletePressed: _deleteArchiveNow,
            );
          }

          if (!couple.isActive) {
            return const _CoupleSettingsMessage(
              title: '지금은 사용할 수 없어요.',
              message: '커플 연결 상태를 다시 확인해 주세요.',
            );
          }

          return _ActiveCoupleSettingsContent(
            isProcessing: _isProcessing,
            onDisconnectPressed: _disconnectCouple,
          );
        },
      ),
    );
  }

  Future<void> _disconnectCouple() async {
    final shouldProceed = await _confirmAction(
      title: '커플 연결을 해제할까요?',
      content:
          '연결을 해제해도 답변과 캐릭터 기록은 30일 동안 보관돼요. 보관 기간 안에는 기존 초대 코드 흐름으로 다시 연결할 수 있어요.',
      confirmLabel: '연결 해제',
    );

    if (!mounted || !shouldProceed) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await ref.read(coupleControllerProvider.notifier).disconnectCouple();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('커플 연결이 해제됐어요.')));
      context.go('/home');
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('커플 연결 해제에 실패했어요.')));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _deleteArchiveNow() async {
    final shouldProceed = await _confirmAction(
      title: '보관 데이터를 지금 삭제할까요?',
      content: '삭제하면 커플, 카드, 답변, 녹음, 캐릭터 데이터가 모두 영구 삭제되고 복구할 수 없어요.',
      confirmLabel: '즉시 삭제',
    );

    if (!mounted || !shouldProceed) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await ref
          .read(coupleControllerProvider.notifier)
          .deleteDisconnectedArchiveNow();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('보관 데이터를 삭제했어요.')));
      context.go('/couple');
    } catch (error, stackTrace) {
      debugPrint('[couple] Failed to delete archived couple data: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('보관 데이터를 삭제하지 못했어요.')));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _reconnectCouple() {
    if (_isProcessing) {
      return;
    }

    context.go('/couple');
  }

  Future<bool> _confirmAction({
    required String title,
    required String content,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result == true;
  }
}

class _ActiveCoupleSettingsContent extends StatelessWidget {
  const _ActiveCoupleSettingsContent({
    required this.isProcessing,
    required this.onDisconnectPressed,
  });

  final bool isProcessing;
  final VoidCallback onDisconnectPressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          '커플 연결을 해제하면 두 사람 모두 읽기 전용 상태로 전환되고, 데이터는 30일 동안 보관돼요.',
          style: AppTextStyles.homeCharacterLabel.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 20),
        AppActionButton(
          label: '커플 연결 해제',
          enabled: !isProcessing,
          isSecondary: true,
          onPressed: onDisconnectPressed,
        ),
      ],
    );
  }
}

class _ArchivedCoupleSettingsContent extends StatelessWidget {
  const _ArchivedCoupleSettingsContent({
    required this.couple,
    required this.isProcessing,
    required this.onReconnectPressed,
    required this.onDeletePressed,
  });

  final Couple couple;
  final bool isProcessing;
  final VoidCallback onReconnectPressed;
  final VoidCallback onDeletePressed;

  @override
  Widget build(BuildContext context) {
    final expiresAt = couple.archiveExpiresAt;

    return ListView(
      children: [
        Text(
          '지금은 기존 기록만 읽기 전용으로 보이고 있어요.',
          style: AppTextStyles.homeBodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          expiresAt == null
              ? '보관 만료 시각을 불러오지 못했어요.'
              : '${_formatDate(expiresAt)}까지 자동 보관 후 영구 삭제돼요.',
          style: AppTextStyles.homeCharacterLabel.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 20),
        AppActionButton(
          label: '다시 연결하기',
          enabled: !isProcessing,
          onPressed: onReconnectPressed,
        ),
        const SizedBox(height: 12),
        AppActionButton(
          label: '보관 데이터 즉시 삭제',
          enabled: !isProcessing,
          isSecondary: true,
          onPressed: onDeletePressed,
        ),
      ],
    );
  }
}

class _CoupleSettingsMessage extends StatelessWidget {
  const _CoupleSettingsMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppTextStyles.homeBodyMedium),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year.$month.$day';
}
