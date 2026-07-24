import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../data/story_card_scene.dart';

class StoryCardTextInputOverlay extends StatefulWidget {
  const StoryCardTextInputOverlay({
    super.key,
    required this.maxLength,
    required this.onCancelled,
    required this.onSubmitted,
  });

  final int maxLength;
  final VoidCallback onCancelled;
  final void Function(String text, Color color) onSubmitted;

  @override
  State<StoryCardTextInputOverlay> createState() =>
      _StoryCardTextInputOverlayState();
}

class _StoryCardTextInputOverlayState extends State<StoryCardTextInputOverlay> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  Color _selectedColor = Colors.white;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return GestureDetector(
      key: const ValueKey('story-card-text-input-overlay'),
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: const Color(0xB3000000),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedPadding(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: TextField(
                      key: const ValueKey('story-card-text-input'),
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      maxLength: widget.maxLength,
                      maxLines: null,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.done,
                      keyboardAppearance: Brightness.dark,
                      style: AppTextStyles.homeBodyMedium.copyWith(
                        color: _selectedColor,
                      ),
                      cursorColor: _selectedColor,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        key: const ValueKey('story-card-text-input-cancel'),
                        tooltip: '텍스트 입력 취소',
                        color: Colors.white,
                        onPressed: widget.onCancelled,
                        icon: const Icon(Icons.close),
                      ),
                      TextButton(
                        key: const ValueKey('story-card-text-input-done'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _submit,
                        child: const Text('완료'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              left: 16,
              right: 16,
              bottom: keyboardInset + 12,
              child: TextFieldTapRegion(
                child: _StoryCardTextColorPalette(
                  selectedColor: _selectedColor,
                  onColorChanged: (color) {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    widget.onSubmitted(_controller.text, _selectedColor);
  }
}

class _StoryCardTextColorPalette extends StatelessWidget {
  const _StoryCardTextColorPalette({
    required this.selectedColor,
    required this.onColorChanged,
  });

  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xC9000000),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          scrollDirection: Axis.horizontal,
          itemCount: storyCardColorPalette.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final color = storyCardColorPalette[index];
            final isSelected = color == selectedColor;
            return Tooltip(
              message: '텍스트 색상 ${index + 1}',
              child: Semantics(
                selected: isSelected,
                button: true,
                child: GestureDetector(
                  key: ValueKey('story-card-text-input-color-$index'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onColorChanged(color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white54,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
