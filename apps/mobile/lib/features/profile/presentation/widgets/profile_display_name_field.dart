import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, Tooltip;
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_input_style.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/profile_display_name_policy.dart';

class ProfileDisplayNameField extends StatefulWidget {
  const ProfileDisplayNameField({
    super.key,
    required this.value,
    required this.isValid,
    required this.onChanged,
    required this.onClear,
    required this.onSubmitted,
    this.autofocus = false,
    this.textInputAction = TextInputAction.done,
  });

  final String value;
  final bool isValid;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onSubmitted;
  final bool autofocus;
  final TextInputAction textInputAction;

  @override
  State<ProfileDisplayNameField> createState() =>
      _ProfileDisplayNameFieldState();
}

class _ProfileDisplayNameFieldState extends State<ProfileDisplayNameField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant ProfileDisplayNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hintColor = widget.isValid
        ? AppColors.success
        : AppColors.textPlaceholder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoTextField(
          key: const Key('profile-display-name-field'),
          controller: _controller,
          autofocus: widget.autofocus,
          keyboardType: TextInputType.name,
          textInputAction: widget.textInputAction,
          inputFormatters: [
            LengthLimitingTextInputFormatter(profileDisplayNameMaxLength),
          ],
          style: AppInputStyle.textStyle,
          placeholder: '닉네임',
          placeholderStyle: AppInputStyle.textStyle.copyWith(
            color: CupertinoColors.placeholderText,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          cursorColor: AppInputStyle.focusColor,
          keyboardAppearance: Brightness.light,
          suffix: widget.value.isEmpty
              ? null
              : Tooltip(
                  message: '입력 지우기',
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(44),
                    onPressed: widget.onClear,
                    child: const Icon(
                      CupertinoIcons.clear_thick_circled,
                      size: 18,
                      color: CupertinoColors.tertiaryLabel,
                    ),
                  ),
                ),
          onChanged: widget.onChanged,
          onSubmitted: (_) {
            if (widget.isValid) {
              widget.onSubmitted();
            }
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(
              widget.isValid ? Icons.check_circle : Icons.info_outline,
              color: hintColor,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '닉네임 $profileDisplayNameMinLength ~ '
              '$profileDisplayNameMaxLength자',
              style: AppTextStyles.onboardingHint.copyWith(color: hintColor),
            ),
          ],
        ),
      ],
    );
  }
}
