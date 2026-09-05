import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../calendar/data/device_calendar_gateway.dart';

Future<DeviceCalendarDescriptor?> showDeviceCalendarSelectionSheet({
  required BuildContext context,
  required List<DeviceCalendarDescriptor> calendars,
}) {
  return showModalBottomSheet<DeviceCalendarDescriptor>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.settingsDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const SizedBox(width: 36, height: 4),
              ),
            ),
            const SizedBox(height: 20),
            const Text('연결할 캘린더', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: calendars.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.settingsDivider),
                itemBuilder: (context, index) {
                  final calendar = calendars[index];
                  return ListTile(
                    key: ValueKey('device-calendar-${calendar.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(calendar.name, style: AppTextStyles.homeBody),
                    subtitle: calendar.accountName == null
                        ? null
                        : Text(
                            calendar.accountName!,
                            style: AppTextStyles.homeCharacterLabel.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                    trailing: calendar.isPrimary
                        ? const Icon(
                            Icons.check_circle_outline_rounded,
                            color: AppColors.textMuted,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(calendar),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
