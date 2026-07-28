import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'app_action_button.dart';

Future<TimeOfDay?> showAppTimePickerSheet({
  required BuildContext context,
  required String title,
  required TimeOfDay initialTime,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        AppTimePickerSheet(title: title, initialTime: initialTime),
  );
}

class AppTimePickerSheet extends StatefulWidget {
  const AppTimePickerSheet({
    super.key,
    required this.title,
    required this.initialTime,
  });

  final String title;
  final TimeOfDay initialTime;

  @override
  State<AppTimePickerSheet> createState() => _AppTimePickerSheetState();
}

class _AppTimePickerSheetState extends State<AppTimePickerSheet> {
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          key: const Key('app-time-picker-sheet'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _SheetHandle()),
              const SizedBox(height: 20),
              Text(widget.title, style: AppTextStyles.sectionTitle),
              const SizedBox(height: 16),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  key: const Key('app-time-picker-wheel'),
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(
                    2000,
                    1,
                    1,
                    _selectedTime.hour,
                    _selectedTime.minute,
                  ),
                  use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                  onDateTimeChanged: (value) {
                    _selectedTime = TimeOfDay.fromDateTime(value);
                  },
                ),
              ),
              const SizedBox(height: 20),
              AppActionButton(
                key: const Key('app-time-picker-complete'),
                label: '완료',
                enabled: true,
                onPressed: () => Navigator.of(context).pop(_selectedTime),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.settingsDivider,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const SizedBox(width: 36, height: 4),
    );
  }
}
