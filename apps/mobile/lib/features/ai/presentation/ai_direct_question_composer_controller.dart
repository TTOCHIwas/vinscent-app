import 'package:flutter/material.dart';

class AiDirectQuestionComposerController extends ChangeNotifier {
  static const maxQuestionLength = 300;

  AiDirectQuestionComposerController() {
    questionController.addListener(_notifyChanged);
    focusNode.addListener(_notifyChanged);
  }

  final TextEditingController questionController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  bool _isSubmitting = false;
  bool _isDisposed = false;

  bool get isSubmitting => _isSubmitting;
  int get characterCount => questionController.text.characters.length;
  String get normalizedQuestion => questionController.text.trim();
  bool get hasValidQuestion =>
      normalizedQuestion.isNotEmpty && characterCount <= maxQuestionLength;

  void setSubmitting(bool value) {
    if (_isDisposed || _isSubmitting == value) {
      return;
    }
    _isSubmitting = value;
    notifyListeners();
  }

  void completeSubmission() {
    if (_isDisposed) {
      return;
    }
    questionController.clear();
    focusNode.unfocus();
  }

  void _notifyChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    questionController
      ..removeListener(_notifyChanged)
      ..dispose();
    focusNode
      ..removeListener(_notifyChanged)
      ..dispose();
    super.dispose();
  }
}
