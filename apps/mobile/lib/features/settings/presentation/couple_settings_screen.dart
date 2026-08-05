import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_icons.dart';
import '../../../core/presentation/widgets/app_confirmation_sheet.dart';
import '../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../../profile/application/profile_controller.dart';
import '../../safety/data/safety_report.dart';
import '../../safety/application/user_block_service.dart';
import '../../safety/presentation/safety_report_sheet.dart';
import 'widgets/settings_group.dart';
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
    final currentUserId = ref
        .watch(profileControllerProvider)
        .maybeWhen(data: (profile) => profile?.id, orElse: () => null);

    return SettingsPageLayout(
      title: '커플 설정',
      onBackPressed: () => context.pop(),
      child: couple.when(
        loading: () => const Center(child: AppLoadingIndicator(strokeWidth: 2)),
        error: (error, stackTrace) => _CoupleSettingsMessage(
          title: '커플 정보를 불러오지 못했어요.',
          message: '잠시 후 다시 시도해 주세요.',
          onRetry: () => ref.read(coupleControllerProvider.notifier).refresh(),
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

          final partnerUserId = _partnerUserId(
            couple: couple,
            currentUserId: currentUserId,
          );
          return _ActiveCoupleSettingsContent(
            relationshipStartDate: couple.relationshipStartDate,
            isProcessing: _isProcessing,
            onRelationshipStartDatePressed: () =>
                context.push('/settings/couple/relationship-date'),
            onDisconnectPressed: _disconnectCouple,
            onBlockPartnerPressed: _blockPartner,
            onReportPartnerPressed: partnerUserId == null
                ? null
                : () => _reportPartner(partnerUserId),
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

  Future<void> _reportPartner(String partnerUserId) {
    return showSafetyReportSheet(
      context: context,
      target: SafetyReportTarget(
        type: SafetyReportTargetType.partner,
        id: partnerUserId,
      ),
    );
  }

  Future<void> _blockPartner() async {
    final shouldProceed = await _confirmAction(
      title: '상대방을 차단할까요?',
      content:
          '차단하면 커플 연결이 즉시 해제되고 두 사람의 공유 기록은 30일 동안 '
          '서로에게 보이지 않아요. 차단을 해제해도 자동으로 다시 연결되지 않아요.',
      confirmLabel: '차단',
    );

    if (!mounted || !shouldProceed) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await ref.read(userBlockServiceProvider).blockCurrentPartner();
      if (!mounted) {
        return;
      }

      context.go('/couple');
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('상대방을 차단하지 못했어요.')));
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
      if (kDebugMode) {
        debugPrint('[couple] Failed to delete archived couple data: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
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
    return showAppConfirmationSheet(
      context: context,
      title: title,
      message: content,
      confirmLabel: confirmLabel,
    );
  }
}

class _ActiveCoupleSettingsContent extends StatelessWidget {
  const _ActiveCoupleSettingsContent({
    required this.relationshipStartDate,
    required this.isProcessing,
    required this.onRelationshipStartDatePressed,
    required this.onDisconnectPressed,
    required this.onBlockPartnerPressed,
    required this.onReportPartnerPressed,
  });

  final DateTime? relationshipStartDate;
  final bool isProcessing;
  final VoidCallback onRelationshipStartDatePressed;
  final VoidCallback onDisconnectPressed;
  final VoidCallback onBlockPartnerPressed;
  final VoidCallback? onReportPartnerPressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SettingsGroup(
          label: '연결 상태',
          children: [
            const SettingsStatusRow(
              icon: AppIcons.heart,
              title: '커플로 연결되어 있어요',
              subtitle: '카드와 답변, 녹음과 캐릭터를 함께 편집할 수 있어요',
              showCompleted: true,
            ),
            if (relationshipStartDate case final relationshipStartDate?)
              SettingsActionRow(
                key: const Key('couple-settings-relationship-date-action'),
                title: '만난 날',
                subtitle: _formatDate(relationshipStartDate),
                enabled: !isProcessing,
                onTap: onRelationshipStartDatePressed,
              ),
          ],
        ),
        const SizedBox(height: 24),
        SettingsGroup(
          label: '안전',
          children: [
            if (onReportPartnerPressed case final onReportPartnerPressed?)
              SettingsActionRow(
                key: const Key('couple-settings-report-partner-action'),
                title: '상대방 신고',
                subtitle: '문제가 있는 행동을 비공개로 알려주세요',
                enabled: !isProcessing,
                onTap: onReportPartnerPressed,
              ),
            SettingsActionRow(
              key: const Key('couple-settings-block-partner-action'),
              title: '상대방 차단',
              subtitle: '연결을 끊고 공유 기록을 서로에게 숨겨요',
              isDestructive: true,
              enabled: !isProcessing,
              onTap: onBlockPartnerPressed,
            ),
          ],
        ),
        const SizedBox(height: 24),
        SettingsGroup(
          label: '연결 관리',
          children: [
            SettingsActionRow(
              key: Key('couple-settings-disconnect-action'),
              title: '커플 연결 해제',
              subtitle: '연결 해제 후에도 기록은 30일 동안 보관돼요',
              isDestructive: true,
              isLoading: isProcessing,
              enabled: !isProcessing,
              onTap: onDisconnectPressed,
            ),
          ],
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
      padding: EdgeInsets.zero,
      children: [
        SettingsGroup(
          label: '보관 상태',
          children: [
            SettingsStatusRow(
              icon: AppIcons.bookmark,
              title: '기록을 보관 중이에요',
              subtitle: expiresAt == null
                  ? '보관 만료일을 불러오지 못했어요'
                  : '${_formatDate(expiresAt)}까지 읽기 전용으로 보관돼요',
            ),
          ],
        ),
        const SizedBox(height: 24),
        SettingsGroup(
          label: '연결 관리',
          children: [
            SettingsActionRow(
              key: const Key('couple-settings-reconnect-action'),
              title: '다시 연결하기',
              subtitle: '기존 기록을 이어서 사용할 수 있어요',
              enabled: !isProcessing,
              onTap: onReconnectPressed,
            ),
            SettingsActionRow(
              key: const Key('couple-settings-delete-action'),
              title: '보관 데이터 즉시 삭제',
              subtitle: '삭제한 기록은 다시 복구할 수 없어요',
              isDestructive: true,
              isLoading: isProcessing,
              enabled: !isProcessing,
              onTap: onDeletePressed,
            ),
          ],
        ),
      ],
    );
  }
}

class _CoupleSettingsMessage extends StatelessWidget {
  const _CoupleSettingsMessage({
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

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
          if (onRetry case final onRetry?) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
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

String? _partnerUserId({
  required Couple couple,
  required String? currentUserId,
}) {
  if (currentUserId == null || !couple.isActive) {
    return null;
  }
  if (couple.userAId == currentUserId) {
    return couple.userBId;
  }
  if (couple.userBId == currentUserId) {
    return couple.userAId;
  }
  return null;
}
