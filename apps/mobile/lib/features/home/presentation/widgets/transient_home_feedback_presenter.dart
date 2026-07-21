import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/home_feedback_impression_store.dart';

typedef TransientHomeFeedbackBuilder =
    Widget Function(String? feedbackText, double feedbackOpacity);

class TransientHomeFeedbackPresenter extends ConsumerStatefulWidget {
  const TransientHomeFeedbackPresenter({
    super.key,
    required this.userId,
    required this.dailyQuestionId,
    required this.feedbackText,
    required this.builder,
  });

  static const displayDuration = Duration(seconds: 8);
  static const fadeDuration = Duration(milliseconds: 240);

  final String? userId;
  final String? dailyQuestionId;
  final String? feedbackText;
  final TransientHomeFeedbackBuilder builder;

  @override
  ConsumerState<TransientHomeFeedbackPresenter> createState() =>
      _TransientHomeFeedbackPresenterState();
}

class _TransientHomeFeedbackPresenterState
    extends ConsumerState<TransientHomeFeedbackPresenter> {
  Timer? _displayTimer;
  Timer? _fadeTimer;
  var _loadRevision = 0;
  var _isVisible = false;
  var _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    _synchronizeFeedback();
  }

  @override
  void didUpdateWidget(covariant TransientHomeFeedbackPresenter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.dailyQuestionId != widget.dailyQuestionId ||
        oldWidget.feedbackText != widget.feedbackText) {
      _synchronizeFeedback();
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      _isVisible ? widget.feedbackText : null,
      _isVisible ? _opacity : 1,
    );
  }

  void _synchronizeFeedback() {
    final revision = ++_loadRevision;
    _cancelTimers();
    _isVisible = false;
    _opacity = 1;

    final userId = widget.userId;
    final dailyQuestionId = widget.dailyQuestionId;
    final feedbackText = widget.feedbackText;
    if (userId == null ||
        dailyQuestionId == null ||
        feedbackText == null ||
        feedbackText.isEmpty) {
      return;
    }

    final store = ref.read(homeFeedbackImpressionStoreProvider);
    unawaited(
      _showIfNeeded(
        store: store,
        userId: userId,
        dailyQuestionId: dailyQuestionId,
        revision: revision,
      ),
    );
  }

  Future<void> _showIfNeeded({
    required HomeFeedbackImpressionStore store,
    required String userId,
    required String dailyQuestionId,
    required int revision,
  }) async {
    var hasShown = false;
    try {
      hasShown = await store.hasShown(
        userId: userId,
        dailyQuestionId: dailyQuestionId,
      );
    } catch (_) {
      hasShown = false;
    }

    if (!mounted || revision != _loadRevision || hasShown) {
      return;
    }

    setState(() {
      _isVisible = true;
      _opacity = 1;
    });
    unawaited(
      _markShown(
        store: store,
        userId: userId,
        dailyQuestionId: dailyQuestionId,
      ),
    );
    _displayTimer = Timer(
      TransientHomeFeedbackPresenter.displayDuration,
      _beginFadeOut,
    );
  }

  Future<void> _markShown({
    required HomeFeedbackImpressionStore store,
    required String userId,
    required String dailyQuestionId,
  }) async {
    try {
      await store.markShown(userId: userId, dailyQuestionId: dailyQuestionId);
    } catch (_) {}
  }

  void _beginFadeOut() {
    if (!mounted || !_isVisible) {
      return;
    }

    setState(() => _opacity = 0);
    _fadeTimer = Timer(TransientHomeFeedbackPresenter.fadeDuration, () {
      if (!mounted) {
        return;
      }
      setState(() => _isVisible = false);
    });
  }

  void _cancelTimers() {
    _displayTimer?.cancel();
    _displayTimer = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;
  }
}
