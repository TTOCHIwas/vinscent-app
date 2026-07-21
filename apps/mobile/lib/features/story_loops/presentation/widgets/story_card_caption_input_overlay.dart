import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../data/story_card_scene.dart';

class StoryCardCaptionInputOverlay extends StatefulWidget {
  const StoryCardCaptionInputOverlay({
    super.key,
    required this.initialValue,
    required this.onCancelled,
    required this.onSubmitted,
  });

  final String initialValue;
  final VoidCallback onCancelled;
  final ValueChanged<String> onSubmitted;

  @override
  State<StoryCardCaptionInputOverlay> createState() =>
      _StoryCardCaptionInputOverlayState();
}

class _StoryCardCaptionInputOverlayState
    extends State<StoryCardCaptionInputOverlay> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
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
      key: const ValueKey('story-card-caption-input-overlay'),
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
                      key: const ValueKey('story-card-caption-input'),
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      maxLength: storyCardMaxCaptionCharacters,
                      maxLines: storyCardMaxCaptionLines,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.newline,
                      keyboardAppearance: Brightness.dark,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          storyCardMaxCaptionCharacters,
                        ),
                        const _MaximumLineCountFormatter(
                          storyCardMaxCaptionLines,
                        ),
                      ],
                      style: AppTextStyles.homeBodyMedium.copyWith(
                        color: Colors.white,
                      ),
                      cursorColor: Colors.white,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
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
                        key: const ValueKey('story-card-caption-input-cancel'),
                        tooltip: '짧은 글 입력 취소',
                        color: Colors.white,
                        onPressed: widget.onCancelled,
                        icon: const Icon(Icons.close),
                      ),
                      TextButton(
                        key: const ValueKey('story-card-caption-input-done'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => widget.onSubmitted(_controller.text),
                        child: const Text('완료'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaximumLineCountFormatter extends TextInputFormatter {
  const _MaximumLineCountFormatter(this.maxLines);

  final int maxLines;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final lines = newValue.text.split(RegExp(r'\r\n?|\n'));
    if (lines.length <= maxLines) {
      return newValue;
    }

    final text = lines.take(maxLines).join('\n');
    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: newValue.selection.baseOffset.clamp(0, text.length).toInt(),
        extentOffset: newValue.selection.extentOffset
            .clamp(0, text.length)
            .toInt(),
      ),
    );
  }
}
