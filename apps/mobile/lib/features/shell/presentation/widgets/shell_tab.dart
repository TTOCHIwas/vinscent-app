import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ShellTab extends StatefulWidget {
  const ShellTab({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  State<ShellTab> createState() => _ShellTabState();
}

class _ShellTabState extends State<ShellTab> {
  static const _feedbackInset = 8.0;
  static const _feedbackRadius = 24.0;
  static const _feedbackDuration = Duration(milliseconds: 120);

  bool _isHighlighted = false;

  void _handleHighlightChanged(bool isHighlighted) {
    if (_isHighlighted == isHighlighted) return;

    setState(() => _isHighlighted = isHighlighted);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: widget.isSelected,
      label: widget.label,
      child: Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            onHighlightChanged: _handleHighlightChanged,
            borderRadius: BorderRadius.circular(32),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: SizedBox.expand(
              child: Padding(
                padding: const EdgeInsets.all(_feedbackInset),
                child: AnimatedContainer(
                  duration: _feedbackDuration,
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: _isHighlighted
                        ? AppColors.shellBottomBarPressed
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(_feedbackRadius),
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      size: 30,
                      color: widget.isSelected
                          ? AppColors.actionPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
