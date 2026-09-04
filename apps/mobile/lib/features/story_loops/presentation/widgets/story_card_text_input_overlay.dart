import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/drawing/widgets/app_color_palette.dart';
import '../../../../core/theme/app_text_styles.dart';

class StoryCardTextInputOverlay extends StatefulWidget {
  const StoryCardTextInputOverlay({
    super.key,
    required this.maxLength,
    required this.onCancelled,
    required this.onSubmitted,
    required this.onPickColor,
  });

  final int maxLength;
  final VoidCallback onCancelled;
  final void Function(String text, Color color) onSubmitted;
  final Future<Color?> Function() onPickColor;

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
                      IconButton(
                        key: const ValueKey('story-card-text-input-done'),
                        tooltip: '텍스트 입력 완료',
                        color: Colors.white,
                        onPressed: _submit,
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              left: 8,
              right: 8,
              bottom: keyboardInset + 12,
              child: TextFieldTapRegion(
                child: AppColorPalette(
                  keyPrefix: 'story-card-text-input',
                  onPickColor: _pickColor,
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

  Future<Color?> _pickColor() async {
    final selection = _controller.selection;
    _focusNode.unfocus();
    try {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      if (!mounted) return null;
      return await widget.onPickColor();
    } finally {
      if (mounted) {
        if (selection.isValid && selection.end <= _controller.text.length) {
          _controller.selection = selection;
        }
        _focusNode.requestFocus();
      }
    }
  }
}
