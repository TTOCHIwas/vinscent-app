import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CoupleStatus(),
          _QuestionCharacterPreview(),
          _ExpressionGrid(),
        ],
      ),
    );
  }
}

class _CoupleStatus extends StatelessWidget {
  const _CoupleStatus();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('ㅇㅇ ♥ ㅇㅇ', style: AppTextStyles.homeBody),
            const SizedBox(height: 4),
            RichText(
              textAlign: TextAlign.end,
              text: const TextSpan(
                children: [
                  TextSpan(text: '사랑한 지 ', style: AppTextStyles.homeBodyMedium),
                  TextSpan(text: '00', style: AppTextStyles.homeDayCount),
                  TextSpan(text: '일 째', style: AppTextStyles.homeBodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCharacterPreview extends StatelessWidget {
  const _QuestionCharacterPreview();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('질문', style: AppTextStyles.homeBodyMedium),
                const SizedBox(height: 36),
                Container(
                  width: 140,
                  height: 140,
                  color: AppColors.wireframePlaceholder,
                  alignment: Alignment.center,
                  child: const Text(
                    '캐릭터',
                    style: AppTextStyles.homeCharacterLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpressionGrid extends StatelessWidget {
  const _ExpressionGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: _ExpressionButton()),
            SizedBox(width: 8),
            Expanded(child: _ExpressionButton()),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _ExpressionButton()),
            SizedBox(width: 8),
            Expanded(child: _ExpressionButton()),
          ],
        ),
      ],
    );
  }
}

class _ExpressionButton extends StatelessWidget {
  const _ExpressionButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.wireframeBorder),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: AppColors.wireframeIcon),
                ),
              ),
              SizedBox(width: 10),
              Text('표현', style: AppTextStyles.homeBody),
            ],
          ),
        ),
      ),
    );
  }
}
