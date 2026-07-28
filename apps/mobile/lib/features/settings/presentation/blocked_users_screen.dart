import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/app_confirmation_sheet.dart';
import '../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../safety/application/user_block_providers.dart';
import '../../safety/application/user_block_service.dart';
import '../../safety/data/user_block.dart';
import 'widgets/settings_group.dart';
import 'widgets/settings_page_layout.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  String? _unblockingUserId;
  String? _actionError;

  @override
  Widget build(BuildContext context) {
    final blockedUsers = ref.watch(blockedUsersProvider);

    return SettingsPageLayout(
      title: '차단한 사용자',
      onBackPressed: _goBack,
      child: blockedUsers.when(
        loading: () => const Center(child: AppLoadingIndicator(strokeWidth: 2)),
        error: (_, _) => _BlockedUsersMessage(
          title: '차단 목록을 불러오지 못했어요',
          message: '잠시 후 다시 시도해 주세요',
          onRetry: () => ref.invalidate(blockedUsersProvider),
        ),
        data: (users) => users.isEmpty
            ? const _BlockedUsersMessage(
                title: '차단한 사용자가 없어요',
                message: '차단한 사용자는 여기에서 관리할 수 있어요',
              )
            : _BlockedUsersContent(
                users: users,
                unblockingUserId: _unblockingUserId,
                errorMessage: _actionError,
                onUnblock: _confirmUnblock,
              ),
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/couple');
  }

  Future<void> _confirmUnblock(BlockedUser user) async {
    final confirmed = await showAppConfirmationSheet(
      context: context,
      title: '${user.displayName}님 차단을 해제할까요?',
      message: '차단을 해제해도 커플 연결과 기록은 자동으로 복구되지 않아요',
      confirmLabel: '차단 해제',
      isDestructive: false,
    );
    if (!mounted || !confirmed) {
      return;
    }

    setState(() {
      _unblockingUserId = user.userId;
      _actionError = null;
    });

    try {
      final wasUnblocked = await ref
          .read(userBlockServiceProvider)
          .unblockUser(user.userId);
      if (!mounted) {
        return;
      }
      if (!wasUnblocked) {
        setState(() {
          _actionError = '이미 차단이 해제된 사용자예요';
        });
      }
      ref.invalidate(blockedUsersProvider);
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionError = '차단을 해제하지 못했어요. 다시 시도해 주세요';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _unblockingUserId = null;
        });
      }
    }
  }
}

class _BlockedUsersContent extends StatelessWidget {
  const _BlockedUsersContent({
    required this.users,
    required this.unblockingUserId,
    required this.errorMessage,
    required this.onUnblock,
  });

  final List<BlockedUser> users;
  final String? unblockingUserId;
  final String? errorMessage;
  final ValueChanged<BlockedUser> onUnblock;

  @override
  Widget build(BuildContext context) {
    final isProcessing = unblockingUserId != null;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (errorMessage case final errorMessage?) ...[
          Text(errorMessage, style: AppTextStyles.compactError),
          const SizedBox(height: 12),
        ],
        SettingsGroup(
          children: [
            for (final user in users)
              SettingsActionRow(
                key: Key('blocked-user-unblock-${user.userId}'),
                title: user.displayName,
                subtitle: '${_formatDate(user.blockedAt)} 차단',
                isLoading: unblockingUserId == user.userId,
                enabled: !isProcessing,
                onTap: () => onUnblock(user),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '차단을 해제해도 이전 커플 연결은 자동으로 복구되지 않아요',
          style: AppTextStyles.homeCharacterLabel.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _BlockedUsersMessage extends StatelessWidget {
  const _BlockedUsersMessage({
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
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year.$month.$day';
}
