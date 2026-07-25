import 'dart:async';

import 'package:flutter/widgets.dart';

typedef PersistentHomeProactiveSuggestionBuilder =
    Widget Function(String? suggestionText, VoidCallback? onDismissed);
typedef PersistentHomeProactiveSuggestionGuard = Future<bool> Function();
typedef PersistentHomeProactiveSuggestionDismissal = Future<void> Function();

class PersistentHomeProactiveSuggestionPresenter extends StatefulWidget {
  const PersistentHomeProactiveSuggestionPresenter({
    super.key,
    required this.presentationId,
    required this.suggestionText,
    required this.enabled,
    required this.builder,
    this.beforeShow,
    this.onDismissed,
  });

  final String? presentationId;
  final String? suggestionText;
  final bool enabled;
  final PersistentHomeProactiveSuggestionBuilder builder;
  final PersistentHomeProactiveSuggestionGuard? beforeShow;
  final PersistentHomeProactiveSuggestionDismissal? onDismissed;

  @override
  State<PersistentHomeProactiveSuggestionPresenter> createState() =>
      _PersistentHomeProactiveSuggestionPresenterState();
}

class _PersistentHomeProactiveSuggestionPresenterState
    extends State<PersistentHomeProactiveSuggestionPresenter> {
  var _revision = 0;
  String? _approvedPresentationId;
  String? _pendingPresentationId;
  String? _rejectedPresentationId;
  String? _dismissedPresentationId;

  @override
  void initState() {
    super.initState();
    _synchronizeSuggestion(suggestionChanged: true);
  }

  @override
  void didUpdateWidget(
    covariant PersistentHomeProactiveSuggestionPresenter oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    final suggestionChanged =
        oldWidget.presentationId != widget.presentationId ||
        oldWidget.suggestionText != widget.suggestionText;
    _synchronizeSuggestion(suggestionChanged: suggestionChanged);
  }

  @override
  void dispose() {
    _revision += 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presentationId = widget.presentationId;
    final suggestionText = widget.suggestionText;
    final isVisible =
        widget.enabled &&
        presentationId != null &&
        suggestionText != null &&
        suggestionText.isNotEmpty &&
        _approvedPresentationId == presentationId &&
        _dismissedPresentationId != presentationId;
    return widget.builder(
      isVisible ? suggestionText : null,
      isVisible ? _dismiss : null,
    );
  }

  void _synchronizeSuggestion({required bool suggestionChanged}) {
    if (suggestionChanged) {
      _revision += 1;
      _approvedPresentationId = null;
      _pendingPresentationId = null;
      _rejectedPresentationId = null;
      _dismissedPresentationId = null;
    }

    final presentationId = widget.presentationId;
    final suggestionText = widget.suggestionText;
    if (!widget.enabled ||
        presentationId == null ||
        suggestionText == null ||
        suggestionText.isEmpty ||
        _approvedPresentationId == presentationId ||
        _pendingPresentationId == presentationId ||
        _rejectedPresentationId == presentationId ||
        _dismissedPresentationId == presentationId) {
      return;
    }

    final revision = _revision;
    _pendingPresentationId = presentationId;
    unawaited(_approveSuggestion(presentationId, revision));
  }

  Future<void> _approveSuggestion(String presentationId, int revision) async {
    var approved = true;
    final beforeShow = widget.beforeShow;
    if (beforeShow != null) {
      try {
        approved = await beforeShow();
      } on Object {
        approved = false;
      }
    }

    if (!mounted ||
        revision != _revision ||
        widget.presentationId != presentationId) {
      return;
    }

    setState(() {
      _pendingPresentationId = null;
      if (approved) {
        _approvedPresentationId = presentationId;
      } else {
        _rejectedPresentationId = presentationId;
      }
    });
  }

  void _dismiss() {
    final presentationId = widget.presentationId;
    if (presentationId == null || _approvedPresentationId != presentationId) {
      return;
    }

    setState(() {
      _dismissedPresentationId = presentationId;
      _approvedPresentationId = null;
    });

    final onDismissed = widget.onDismissed;
    if (onDismissed != null) {
      unawaited(_notifyDismissed(onDismissed));
    }
  }

  Future<void> _notifyDismissed(
    PersistentHomeProactiveSuggestionDismissal onDismissed,
  ) async {
    try {
      await onDismissed();
    } on Object {
      return;
    }
  }
}
