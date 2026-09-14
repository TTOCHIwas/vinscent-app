import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

Future<Color?> showAppHsvColorPickerSheet({
  required BuildContext context,
  required Color initialColor,
}) {
  return showModalBottomSheet<Color>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => AppHsvColorPickerSheet(initialColor: initialColor),
  );
}

class AppHsvColorPickerSheet extends StatefulWidget {
  const AppHsvColorPickerSheet({super.key, required this.initialColor});

  final Color initialColor;

  @override
  State<AppHsvColorPickerSheet> createState() => _AppHsvColorPickerSheetState();
}

class _AppHsvColorPickerSheetState extends State<AppHsvColorPickerSheet> {
  late HSVColor _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = HSVColor.fromColor(widget.initialColor).withAlpha(1);
  }

  @override
  Widget build(BuildContext context) {
    final color = _selectedColor.toColor();
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey('app-hsv-color-picker-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.settingsDivider,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
                child: SizedBox(width: 36, height: 4),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text('배경 색상', style: AppTextStyles.sectionTitle),
                ),
                DecoratedBox(
                  key: const ValueKey('app-hsv-color-picker-preview'),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.settingsDivider),
                  ),
                  child: const SizedBox.square(dimension: 32),
                ),
                const SizedBox(width: 10),
                Text(
                  _hexLabel(color),
                  style: AppTextStyles.homeBody.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _SaturationValueField(
                  color: _selectedColor,
                  onChanged: (value) => setState(() => _selectedColor = value),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _HueSlider(
              color: _selectedColor,
              onChanged: (value) => setState(() => _selectedColor = value),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('app-hsv-color-picker-cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: const ValueKey('app-hsv-color-picker-apply'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandAction,
                  ),
                  onPressed: () => Navigator.of(context).pop(color),
                  child: const Text('적용'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _hexLabel(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

class _SaturationValueField extends StatelessWidget {
  const _SaturationValueField({required this.color, required this.onChanged});

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        void update(Offset position) {
          final saturation = (position.dx / size.width).clamp(0.0, 1.0);
          final value = 1 - (position.dy / size.height).clamp(0.0, 1.0);
          onChanged(color.withSaturation(saturation).withValue(value));
        }

        return GestureDetector(
          key: const ValueKey('app-hsv-color-picker-field'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => update(details.localPosition),
          onPanStart: (details) => update(details.localPosition),
          onPanUpdate: (details) => update(details.localPosition),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
                    ),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.transparent],
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: color.saturation * size.width - 10,
                top: (1 - color.value) * size.height - 10,
                child: _ColorThumb(color: color.toColor()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.color, required this.onChanged});

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void update(Offset position) {
          final hue = (position.dx / width).clamp(0.0, 1.0) * 360;
          onChanged(color.withHue(hue));
        }

        return GestureDetector(
          key: const ValueKey('app-hsv-color-picker-hue'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => update(details.localPosition),
          onPanStart: (details) => update(details.localPosition),
          onPanUpdate: (details) => update(details.localPosition),
          child: SizedBox(
            height: 32,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                const Positioned.fill(
                  top: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFFFFFF00),
                          Color(0xFF00FF00),
                          Color(0xFF00FFFF),
                          Color(0xFF0000FF),
                          Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: (color.hue / 360) * width - 10,
                  child: _ColorThumb(
                    color: HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ColorThumb extends StatelessWidget {
  const _ColorThumb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x52000000), blurRadius: 4)],
      ),
      child: const SizedBox.square(dimension: 20),
    );
  }
}
