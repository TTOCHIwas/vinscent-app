import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_icons.dart';
import '../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../notifications/data/notification_permission_repository.dart';
import '../application/notification_permission_controller.dart';
import '../application/notification_preferences_controller.dart';
import '../data/notification_preferences.dart';
import 'widgets/settings_group.dart';
import 'widgets/settings_page_layout.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  bool _isPermissionActionRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref.read(notificationPermissionControllerProvider.notifier).refresh(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(notificationPreferencesControllerProvider);
    final permission = ref.watch(notificationPermissionControllerProvider);

    return SettingsPageLayout(
      title: '알림 설정',
      onBackPressed: () => context.pop(),
      child: preferences.when(
        loading: () => const Center(child: AppLoadingIndicator(strokeWidth: 2)),
        error: (error, stackTrace) => _SettingsLoadError(
          onRetry: () => ref
              .read(notificationPreferencesControllerProvider.notifier)
              .refresh(),
        ),
        data: (preferences) => _NotificationSettingsContent(
          preferences: preferences,
          permission: permission,
          isPermissionActionRunning: _isPermissionActionRunning,
          onPermissionAction: _handlePermissionAction,
          onPermissionRetry: () => ref
              .read(notificationPermissionControllerProvider.notifier)
              .refresh(),
        ),
      ),
    );
  }

  Future<void> _handlePermissionAction(
    NotificationPermissionStatus status,
  ) async {
    if (_isPermissionActionRunning) {
      return;
    }

    setState(() {
      _isPermissionActionRunning = true;
    });

    try {
      final controller = ref.read(
        notificationPermissionControllerProvider.notifier,
      );
      switch (status) {
        case NotificationPermissionStatus.denied:
          await controller.openSettings();
        case NotificationPermissionStatus.notDetermined:
          await controller.requestPermission();
        case NotificationPermissionStatus.enabled:
        case NotificationPermissionStatus.unsupported:
          break;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('기기 알림 설정을 열지 못했어요.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPermissionActionRunning = false;
        });
      }
    }
  }
}

class _NotificationSettingsContent extends ConsumerWidget {
  const _NotificationSettingsContent({
    required this.preferences,
    required this.permission,
    required this.isPermissionActionRunning,
    required this.onPermissionAction,
    required this.onPermissionRetry,
  });

  final NotificationPreferences preferences;
  final AsyncValue<NotificationPermissionStatus> permission;
  final bool isPermissionActionRunning;
  final ValueChanged<NotificationPermissionStatus> onPermissionAction;
  final VoidCallback onPermissionRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      notificationPreferencesControllerProvider.notifier,
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _NotificationPermissionGroup(
          permission: permission,
          isActionRunning: isPermissionActionRunning,
          onAction: onPermissionAction,
          onRetry: onPermissionRetry,
        ),
        const SizedBox(height: 24),
        SettingsGroup(
          key: const Key('notification-settings-card-question-group'),
          label: '카드와 질문',
          children: [
            SettingsToggleRow(
              title: '상대가 카드를 올렸을 때',
              value: preferences.partnerStoryCardEnabled,
              onChanged: (value) => _updatePreferences(
                context: context,
                update: controller.updatePreferences(
                  preferences.copyWith(partnerStoryCardEnabled: value),
                ),
              ),
            ),
            SettingsToggleRow(
              title: '새 질문이 도착했을 때',
              value: preferences.dailyQuestionEnabled,
              onChanged: (value) => _updatePreferences(
                context: context,
                update: controller.updatePreferences(
                  preferences.copyWith(dailyQuestionEnabled: value),
                ),
              ),
            ),
            SettingsToggleRow(
              title: '상대가 답변했을 때',
              value: preferences.partnerAnswerEnabled,
              onChanged: (value) => _updatePreferences(
                context: context,
                update: controller.updatePreferences(
                  preferences.copyWith(partnerAnswerEnabled: value),
                ),
              ),
            ),
            SettingsToggleRow(
              title: '답하지 않은 질문 알림',
              value: preferences.reminderEnabled,
              onChanged: (value) => _updatePreferences(
                context: context,
                update: controller.updatePreferences(
                  preferences.copyWith(reminderEnabled: value),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SettingsGroup(
          key: const Key('notification-settings-recording-group'),
          label: '녹음',
          children: [
            SettingsToggleRow(
              title: '녹음과 보관함 소식',
              subtitle: '새 녹음과 슬롯 변경 소식을 받아요',
              value: preferences.recordingEnabled,
              onChanged: (value) => _updatePreferences(
                context: context,
                update: controller.updatePreferences(
                  preferences.copyWith(recordingEnabled: value),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SettingsGroup(
          key: const Key('notification-settings-couple-group'),
          label: '둘의 공간',
          children: [
            SettingsToggleRow(
              title: '연결과 캐릭터 소식',
              subtitle: '연결 상태와 캐릭터 변경 소식을 받아요',
              value: preferences.coupleActivityEnabled,
              onChanged: (value) => _updatePreferences(
                context: context,
                update: controller.updatePreferences(
                  preferences.copyWith(coupleActivityEnabled: value),
                ),
              ),
            ),
            SettingsToggleRow(
              title: '커플 연결 해제 알림',
              value: preferences.coupleDisconnectEnabled,
              onChanged: (value) => _updatePreferences(
                context: context,
                update: controller.updatePreferences(
                  preferences.copyWith(coupleDisconnectEnabled: value),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SettingsGroup(
          key: const Key('notification-settings-character-group'),
          label: '캐릭터',
          children: [
            SettingsToggleRow(
              title: '캐릭터가 전하는 소식',
              subtitle: '답변과 기억이 준비되면 알려줘요',
              value: preferences.aiUpdatesEnabled,
              onChanged: (value) => _updatePreferences(
                context: context,
                update: controller.updatePreferences(
                  preferences.copyWith(aiUpdatesEnabled: value),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _updatePreferences({
    required BuildContext context,
    required Future<void> update,
  }) async {
    try {
      await update;
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('알림 설정을 저장하지 못했어요.')));
    }
  }
}

class _NotificationPermissionGroup extends StatelessWidget {
  const _NotificationPermissionGroup({
    required this.permission,
    required this.isActionRunning,
    required this.onAction,
    required this.onRetry,
  });

  final AsyncValue<NotificationPermissionStatus> permission;
  final bool isActionRunning;
  final ValueChanged<NotificationPermissionStatus> onAction;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      key: const Key('notification-settings-device-group'),
      label: '기기',
      children: [
        permission.when(
          loading: () => const SettingsStatusRow(
            icon: AppIcons.alarm,
            title: '기기 알림 확인 중',
            subtitle: '현재 권한 상태를 확인하고 있어요',
            isActionLoading: true,
          ),
          error: (error, stackTrace) => SettingsStatusRow(
            icon: AppIcons.alarm,
            title: '기기 알림 상태를 확인하지 못했어요',
            subtitle: '잠시 후 다시 확인해 주세요',
            actionLabel: '다시 시도',
            onActionPressed: onRetry,
          ),
          data: (status) {
            final content = _permissionContent(status);
            return SettingsStatusRow(
              icon: AppIcons.alarm,
              title: content.title,
              subtitle: content.subtitle,
              actionLabel: content.actionLabel,
              onActionPressed: content.actionLabel == null
                  ? null
                  : () => onAction(status),
              isActionLoading: isActionRunning,
              showCompleted: status == NotificationPermissionStatus.enabled,
              completedColor: AppColors.brandAccent,
            );
          },
        ),
      ],
    );
  }

  _NotificationPermissionContent _permissionContent(
    NotificationPermissionStatus status,
  ) {
    return switch (status) {
      NotificationPermissionStatus.enabled =>
        const _NotificationPermissionContent(
          title: '알림을 받을 수 있어요',
          subtitle: '단짠의 기기 알림이 허용되어 있어요',
        ),
      NotificationPermissionStatus.denied =>
        const _NotificationPermissionContent(
          title: '기기 알림이 꺼져 있어요',
          subtitle: '아래 알림을 켜도 기기 설정이 꺼져 있으면 받을 수 없어요',
          actionLabel: '설정 열기',
        ),
      NotificationPermissionStatus.notDetermined =>
        const _NotificationPermissionContent(
          title: '기기 알림을 켜주세요',
          subtitle: '알림을 받으려면 먼저 기기 권한을 허용해 주세요',
          actionLabel: '허용하기',
        ),
      NotificationPermissionStatus.unsupported =>
        const _NotificationPermissionContent(
          title: '기기 알림을 사용할 수 없어요',
          subtitle: '현재 기기에서는 푸시 알림을 지원하지 않아요',
        ),
    };
  }
}

class _NotificationPermissionContent {
  const _NotificationPermissionContent({
    required this.title,
    required this.subtitle,
    this.actionLabel,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
}

class _SettingsLoadError extends StatelessWidget {
  const _SettingsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('설정을 불러오지 못했어요.', style: AppTextStyles.homeBodyMedium),
          const SizedBox(height: 8),
          Text(
            '잠시 후 다시 시도해 주세요.',
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
