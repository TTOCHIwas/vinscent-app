import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

enum StoryCardDraftExitAction { saveDraft, discard, continueEditing }

Future<StoryCardDraftExitAction?> showStoryCardDraftExitDialog({
  required BuildContext context,
}) {
  return showDialog<StoryCardDraftExitAction>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) => const StoryCardDraftExitDialog(),
  );
}

class StoryCardDraftExitDialog extends StatelessWidget {
  const StoryCardDraftExitDialog({super.key});

  static const _screenInset = 24.0;
  static const _horizontalInset = 24.0;
  static const _maximumWidth = 400.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            (constraints.maxWidth -
                    MediaQuery.viewInsetsOf(context).horizontal -
                    _screenInset * 2)
                .clamp(0.0, _maximumWidth);
        final maxTextWidth = (maxWidth - _horizontalInset * 2).clamp(
          0.0,
          _maximumWidth,
        );

        return AlertDialog(
          key: const ValueKey('story-card-draft-exit-dialog'),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.all(_screenInset),
          contentPadding: EdgeInsets.zero,
          constraints: BoxConstraints(maxWidth: maxWidth),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _horizontalInset,
                      28,
                      _horizontalInset,
                      24,
                    ),
                    child: _DialogText(
                      '임시 저장할까요?',
                      maxWidth: maxTextWidth,
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                ),
              ),
              const _Divider(),
              _Action(
                buttonKey: const ValueKey('story-card-draft-exit-save'),
                label: '임시 저장',
                color: AppColors.brandAction,
                result: StoryCardDraftExitAction.saveDraft,
                maxTextWidth: maxTextWidth,
              ),
              const _Divider(),
              _Action(
                buttonKey: const ValueKey('story-card-draft-exit-discard'),
                label: '버리기',
                color: Theme.of(context).colorScheme.error,
                result: StoryCardDraftExitAction.discard,
                maxTextWidth: maxTextWidth,
              ),
              const _Divider(),
              _Action(
                buttonKey: const ValueKey('story-card-draft-exit-continue'),
                label: '계속 수정',
                color: AppColors.textPrimary,
                result: StoryCardDraftExitAction.continueEditing,
                maxTextWidth: maxTextWidth,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.settingsDivider,
      child: SizedBox(height: 1),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.buttonKey,
    required this.label,
    required this.color,
    required this.result,
    required this.maxTextWidth,
  });

  final Key buttonKey;
  final String label;
  final Color color;
  final StoryCardDraftExitAction result;
  final double maxTextWidth;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: buttonKey,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(
          horizontal: StoryCardDraftExitDialog._horizontalInset,
          vertical: 16,
        ),
        textStyle: AppTextStyles.homeBodyMedium,
        shape: const RoundedRectangleBorder(),
      ),
      onPressed: () => Navigator.of(context).pop(result),
      child: _DialogText(
        label,
        maxWidth: maxTextWidth,
        style: AppTextStyles.homeBodyMedium,
      ),
    );
  }
}

class _DialogText extends StatelessWidget {
  const _DialogText(this.text, {required this.maxWidth, required this.style});

  final String text;
  final double maxWidth;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final displayText = keepWordsTogether(
      text,
      maxTextWidth: maxWidth,
      style: style,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );
    return Text(
      displayText,
      textAlign: TextAlign.center,
      style: style,
      semanticsLabel: text,
    );
  }
}
