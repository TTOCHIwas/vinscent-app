import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/notification_preferences_controller.dart';
import '../data/notification_preferences.dart';
import 'widgets/settings_page_header.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsPageHeader(
              title: '알림 설정',
              onBackPressed: () => context.pop(),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: preferences.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (error, stackTrace) => _SettingsLoadError(
                  onRetry: () => ref
                      .read(notificationPreferencesControllerProvider.notifier)
                      .refresh(),
                ),
                data: (preferences) =>
                    _NotificationSettingsContent(preferences: preferences),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSettingsContent extends ConsumerWidget {
  const _NotificationSettingsContent({required this.preferences});

  final NotificationPreferences preferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      notificationPreferencesControllerProvider.notifier,
    );

    return ListView(
      children: [
        _TimeSettingCard(
          title: '오늘 질문 도착 시각',
          timeLabel: _formatTimeOfDay(preferences.dailyQuestionDeliveryTime),
          description:
              '미답변 리마인드는 ${_formatTimeOfDay(preferences.reminderDeliveryTime)}에 고정으로 발송돼요.',
          onTap: () async {
            final pickedTime = await showTimePicker(
              context: context,
              initialTime: preferences.dailyQuestionDeliveryTime,
            );

            if (pickedTime == null || !context.mounted) {
              return;
            }

            await _updatePreferences(
              context: context,
              update: controller.updatePreferences(
                preferences.copyWith(dailyQuestionDeliveryTime: pickedTime),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        _PreferenceToggleTile(
          title: '표현 알림',
          value: preferences.expressionEnabled,
          onChanged: (value) => _updatePreferences(
            context: context,
            update: controller.updatePreferences(
              preferences.copyWith(expressionEnabled: value),
            ),
          ),
        ),
        _PreferenceToggleTile(
          title: '상대 답변 완료',
          value: preferences.partnerAnswerEnabled,
          onChanged: (value) => _updatePreferences(
            context: context,
            update: controller.updatePreferences(
              preferences.copyWith(partnerAnswerEnabled: value),
            ),
          ),
        ),
        _PreferenceToggleTile(
          title: '오늘 질문 도착',
          value: preferences.dailyQuestionEnabled,
          onChanged: (value) => _updatePreferences(
            context: context,
            update: controller.updatePreferences(
              preferences.copyWith(dailyQuestionEnabled: value),
            ),
          ),
        ),
        _PreferenceToggleTile(
          title: '미답변 리마인드',
          value: preferences.reminderEnabled,
          onChanged: (value) => _updatePreferences(
            context: context,
            update: controller.updatePreferences(
              preferences.copyWith(reminderEnabled: value),
            ),
          ),
        ),
        _PreferenceToggleTile(
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

class _TimeSettingCard extends StatelessWidget {
  const _TimeSettingCard({
    required this.title,
    required this.timeLabel,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String timeLabel;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.wireframeBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.homeBodyMedium),
              const SizedBox(height: 8),
              Text(timeLabel, style: AppTextStyles.onboardingTitle),
              const SizedBox(height: 8),
              Text(
                description,
                style: AppTextStyles.homeCharacterLabel.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferenceToggleTile extends StatelessWidget {
  const _PreferenceToggleTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.wireframeBorder)),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: AppTextStyles.homeBody),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
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

String _formatTimeOfDay(TimeOfDay value) {
  final period = value.hour >= 12 ? '오후' : '오전';
  final hour = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$period $hour:$minute';
}
