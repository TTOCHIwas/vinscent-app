import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

enum CoupleConnectionMode { createInvite, enterCode }

class CoupleConnectionModeSelector extends StatelessWidget {
  const CoupleConnectionModeSelector({
    super.key,
    required this.selectedMode,
    required this.onSelected,
  });

  final CoupleConnectionMode selectedMode;
  final ValueChanged<CoupleConnectionMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('couple-connection-mode-selector'),
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.formSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ModeItem(
              label: '초대하기',
              icon: Icons.link,
              selected: selectedMode == CoupleConnectionMode.createInvite,
              onTap: () => onSelected(CoupleConnectionMode.createInvite),
            ),
          ),
          Expanded(
            child: _ModeItem(
              label: '코드 입력',
              icon: Icons.keyboard_alt_outlined,
              selected: selectedMode == CoupleConnectionMode.enterCode,
              onTap: () => onSelected(CoupleConnectionMode.enterCode),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeItem extends StatelessWidget {
  const _ModeItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.background : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: AppTextStyles.homeBodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
