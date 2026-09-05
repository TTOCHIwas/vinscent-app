import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_icons.dart';
import '../../../core/presentation/widgets/app_confirmation_dialog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../calendar/application/device_calendar_settings_controller.dart';
import '../../calendar/application/public_holiday_controller.dart';
import '../../calendar/data/device_calendar_gateway.dart';
import '../../calendar/data/public_holiday.dart';
import 'widgets/device_calendar_selection_sheet.dart';
import 'widgets/settings_group.dart';
import 'widgets/settings_page_layout.dart';

class CalendarSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSettingsScreen> createState() =>
      _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState extends ConsumerState<CalendarSettingsScreen>
    with WidgetsBindingObserver {
  bool _isActionRunning = false;

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
      ref.read(deviceCalendarSettingsControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final holidayRegion = ref.watch(publicHolidayRegionControllerProvider);
    final deviceSettings = ref.watch(deviceCalendarSettingsControllerProvider);

    return SettingsPageLayout(
      title: '캘린더 설정',
      onBackPressed: () => context.pop(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SettingsGroup(
            label: '공휴일',
            children: [
              holidayRegion.when(
                loading: () => const SettingsStatusRow(
                  icon: AppIcons.calendar,
                  title: '공휴일 설정 확인 중',
                  subtitle: '기기 지역에 맞는 설정을 확인하고 있어요',
                  isActionLoading: true,
                ),
                error: (error, stackTrace) => SettingsStatusRow(
                  icon: AppIcons.calendar,
                  title: '공휴일 설정을 불러오지 못했어요',
                  subtitle: '잠시 후 다시 확인해 주세요',
                  actionLabel: '다시 시도',
                  onActionPressed: () =>
                      ref.invalidate(publicHolidayRegionControllerProvider),
                ),
                data: (region) => SettingsToggleRow(
                  key: const Key('south-korea-holiday-toggle'),
                  title: '대한민국 공휴일 표시',
                  subtitle: '달력 날짜와 선택한 날의 공휴일 이름을 보여줘요',
                  value: region == PublicHolidayRegion.southKorea,
                  onChanged: _isActionRunning
                      ? (_) {}
                      : (value) => _updateHolidayRegion(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            label: '기기 캘린더',
            children: [
              deviceSettings.when(
                loading: () => const SettingsStatusRow(
                  icon: AppIcons.calendar,
                  title: '동기화 설정 확인 중',
                  subtitle: '이 기기의 캘린더 연결 상태를 확인하고 있어요',
                  isActionLoading: true,
                ),
                error: (error, stackTrace) => SettingsStatusRow(
                  icon: AppIcons.calendar,
                  title: '동기화 설정을 불러오지 못했어요',
                  subtitle: '잠시 후 다시 확인해 주세요',
                  actionLabel: '다시 시도',
                  onActionPressed: () =>
                      ref.invalidate(deviceCalendarSettingsControllerProvider),
                ),
                data: (settings) => SettingsToggleRow(
                  key: const Key('device-calendar-sync-toggle'),
                  title: '기기 캘린더에 일정 표시',
                  subtitle: settings.isEnabled
                      ? '${settings.sync.calendar!.name}에 연결되어 있어요'
                      : '단짠에서 만든 일정을 선택한 캘린더에 추가해요',
                  value: settings.isEnabled,
                  onChanged: _isActionRunning
                      ? (_) {}
                      : (value) => value
                            ? _enableDeviceCalendarSync()
                            : _disableDeviceCalendarSync(),
                ),
              ),
              if (deviceSettings.asData?.value.isEnabled == true)
                SettingsActionRow(
                  title: '일정 다시 동기화',
                  subtitle: deviceSettings.asData!.value.hasPendingOperations
                      ? '처리하지 못한 일정이 있어 다시 시도해요'
                      : '단짠 일정 상태를 기기 캘린더에 다시 반영해요',
                  isLoading: _isActionRunning,
                  onTap: _resynchronize,
                ),
              if (deviceSettings.asData case AsyncData(
                :final value,
              ) when value.hasPendingOperations && !value.isEnabled)
                SettingsActionRow(
                  title: '남은 기기 일정 정리',
                  subtitle: '권한을 허용한 뒤 삭제하지 못한 일정을 정리해요',
                  isLoading: _isActionRunning,
                  onTap: _resynchronize,
                ),
              if (deviceSettings.asData case AsyncData(:final value)
                  when value.authorization ==
                          DeviceCalendarAuthorizationStatus.denied &&
                      (value.isEnabled || value.hasPendingOperations))
                SettingsActionRow(
                  title: '기기 설정에서 권한 허용',
                  subtitle: '캘린더 일정을 다시 동기화하려면 권한이 필요해요',
                  isLoading: _isActionRunning,
                  onTap: _openDeviceSettings,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateHolidayRegion(bool enabled) async {
    await _runAction(
      () => ref
          .read(publicHolidayRegionControllerProvider.notifier)
          .select(
            enabled ? PublicHolidayRegion.southKorea : PublicHolidayRegion.off,
          ),
      failureMessage: '공휴일 설정을 저장하지 못했어요',
    );
  }

  Future<void> _enableDeviceCalendarSync() async {
    if (_isActionRunning) {
      return;
    }
    setState(() => _isActionRunning = true);
    try {
      final controller = ref.read(
        deviceCalendarSettingsControllerProvider.notifier,
      );
      final settings = await controller.requestAccessAndLoadCalendars();
      if (!mounted) {
        return;
      }
      if (settings.authorization !=
          DeviceCalendarAuthorizationStatus.authorized) {
        if (settings.authorization ==
            DeviceCalendarAuthorizationStatus.denied) {
          await controller.openSettings();
        } else if (settings.authorization ==
            DeviceCalendarAuthorizationStatus.restricted) {
          _showMessage('기기 제한 설정으로 캘린더 권한을 사용할 수 없어요');
        } else {
          _showMessage('이 기기에서는 캘린더 동기화를 사용할 수 없어요');
        }
        return;
      }
      if (settings.writableCalendars.isEmpty) {
        _showMessage('일정을 추가할 수 있는 기기 캘린더가 없어요');
        return;
      }

      final calendar = await showDeviceCalendarSelectionSheet(
        context: context,
        calendars: settings.writableCalendars,
      );
      if (!mounted || calendar == null) {
        return;
      }
      final includeExisting = await showAppConfirmationDialog(
        context: context,
        title: '기존 일정도 추가할까요?',
        message: '오늘 이후 일정과 매년 반복되는 일정을 함께 추가할 수 있어요.',
        confirmLabel: '기존 일정도 추가',
        cancelLabel: '앞으로 만든 일정만',
        isDestructive: false,
      );
      await controller.enable(
        calendar: calendar,
        includeExistingEvents: includeExisting,
      );
    } catch (_) {
      if (mounted) {
        _showMessage('기기 캘린더 동기화를 켜지 못했어요');
      }
    } finally {
      if (mounted) {
        setState(() => _isActionRunning = false);
      }
    }
  }

  Future<void> _disableDeviceCalendarSync() async {
    final choice = await _showDisableChoice();
    if (choice == null || !mounted) {
      return;
    }
    await _runAction(
      () => ref
          .read(deviceCalendarSettingsControllerProvider.notifier)
          .disable(
            deleteMirroredEvents:
                choice == _DeviceCalendarDisableChoice.deleteEvents,
          ),
      failureMessage: '기기 캘린더 동기화를 끄지 못했어요',
    );
  }

  Future<_DeviceCalendarDisableChoice?> _showDisableChoice() {
    return showDialog<_DeviceCalendarDisableChoice>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('기기 캘린더 동기화를 끌까요?', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            Text(
              '단짠 일정은 그대로 유지됩니다.',
              style: AppTextStyles.homeBody.copyWith(
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(_DeviceCalendarDisableChoice.deleteEvents),
              child: Text(
                '기기 일정도 삭제',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(_DeviceCalendarDisableChoice.stopOnly),
              child: const Text('동기화만 중지'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resynchronize() async {
    await _runAction(
      () => ref
          .read(deviceCalendarSettingsControllerProvider.notifier)
          .resynchronize(),
      failureMessage: '일정을 다시 동기화하지 못했어요',
    );
  }

  Future<void> _openDeviceSettings() async {
    await _runAction(
      () => ref
          .read(deviceCalendarSettingsControllerProvider.notifier)
          .openSettings(),
      failureMessage: '기기 설정을 열지 못했어요',
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String failureMessage,
  }) async {
    if (_isActionRunning) {
      return;
    }
    setState(() => _isActionRunning = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        _showMessage(failureMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isActionRunning = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _DeviceCalendarDisableChoice { stopOnly, deleteEvents }
