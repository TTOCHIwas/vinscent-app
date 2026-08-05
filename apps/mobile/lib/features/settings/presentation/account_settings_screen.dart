import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/app_confirmation_sheet.dart';
import '../../account/application/account_deletion_controller.dart';
import '../../account/data/account_deletion_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../profile/application/profile_controller.dart';
import 'widgets/settings_group.dart';
import 'widgets/settings_page_layout.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  var _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    final deletionState = ref.watch(accountDeletionControllerProvider);
    final profile = ref.watch(profileControllerProvider);

    return SettingsPageLayout(
      title: '계정',
      onBackPressed: () => context.pop(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SettingsGroup(
            label: '프로필',
            children: [
              SettingsActionRow(
                key: const Key('account-settings-display-name-action'),
                title: '닉네임',
                subtitle: profile.maybeWhen(
                  data: (profile) => profile?.displayName ?? '프로필을 확인해 주세요',
                  loading: () => '불러오는 중',
                  orElse: () => '프로필을 불러오지 못했어요',
                ),
                enabled:
                    profile.asData?.value != null &&
                    !_isSigningOut &&
                    !deletionState.isDeleting,
                onTap: () => context.push('/settings/account/nickname'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            label: '계정 관리',
            children: [
              SettingsActionRow(
                key: const Key('account-settings-sign-out-action'),
                title: '로그아웃',
                subtitle: '이 기기에서만 로그아웃해요',
                isLoading: _isSigningOut,
                enabled: !deletionState.isDeleting,
                onTap: _confirmSignOut,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            label: '데이터',
            children: [
              SettingsActionRow(
                key: const Key('account-settings-delete-action'),
                title: '계정 삭제',
                subtitle: '계정과 커플의 공유 데이터를 영구 삭제해요',
                isDestructive: true,
                isLoading: deletionState.isDeleting,
                enabled: !_isSigningOut,
                onTap: _confirmDeleteAccount,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showAppConfirmationSheet(
      context: context,
      title: '로그아웃할까요?',
      message: '이 기기의 계정 연결만 해제되고 저장된 데이터는 삭제되지 않아요',
      confirmLabel: '로그아웃',
      isDestructive: false,
    );
    if (!mounted || !confirmed) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });
    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (_) {
      if (mounted) {
        _showMessage('로그아웃하지 못했어요. 다시 시도해 주세요');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showAppConfirmationSheet(
      context: context,
      title: '계정을 삭제할까요?',
      message:
          '계정과 두 사람이 함께 만든 카드, 녹음, 답변, 캐릭터, 일정, AI 데이터가 '
          '모두 영구 삭제돼요. 상대방 계정은 유지되지만 커플 연결은 해제되며, '
          '삭제한 데이터는 복구할 수 없어요',
      confirmLabel: '계정 삭제',
    );
    if (!mounted || !confirmed) {
      return;
    }

    final deleted = await ref
        .read(accountDeletionControllerProvider.notifier)
        .deleteAccount();
    if (!mounted || deleted) {
      return;
    }

    final failureReason = ref
        .read(accountDeletionControllerProvider)
        .failureReason;
    _showMessage(_deletionFailureMessage(failureReason));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _deletionFailureMessage(AccountDeletionFailureReason? reason) {
    return switch (reason) {
      AccountDeletionFailureReason.configMissing => '서비스 설정을 확인해 주세요',
      AccountDeletionFailureReason.sessionExpired =>
        '로그인 세션이 만료됐어요. 다시 로그인해 주세요',
      AccountDeletionFailureReason.reauthenticationRequired =>
        'Apple 로그인 확인이 필요해요. 다시 시도해 주세요',
      AccountDeletionFailureReason.reauthenticationCancelled =>
        'Apple 로그인 확인을 취소했어요',
      AccountDeletionFailureReason.reauthenticationFailed =>
        'Apple 로그인 확인을 완료하지 못했어요. 다시 시도해 주세요',
      AccountDeletionFailureReason.requestTimeout => '요청 시간이 초과됐어요. 다시 시도해 주세요',
      AccountDeletionFailureReason.requestFailed ||
      AccountDeletionFailureReason.invalidResponse ||
      AccountDeletionFailureReason.unknown ||
      null => '계정을 삭제하지 못했어요. 잠시 후 다시 시도해 주세요',
    };
  }
}
