import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_proactive_suggestion.dart';
import '../data/ai_proactive_suggestion_repository.dart';
import '../data/ai_proactive_suggestion_store.dart';
import 'ai_current_location_service.dart';

@immutable
class AiProactiveSuggestionRequest {
  const AiProactiveSuggestionRequest({
    required this.userId,
    required this.sessionId,
    required this.contextDate,
    required this.hasCardToday,
  });

  final String userId;
  final String sessionId;
  final String contextDate;
  final bool hasCardToday;

  @override
  bool operator ==(Object other) {
    return other is AiProactiveSuggestionRequest &&
        other.userId == userId &&
        other.sessionId == sessionId &&
        other.contextDate == contextDate &&
        other.hasCardToday == hasCardToday;
  }

  @override
  int get hashCode => Object.hash(userId, sessionId, contextDate, hasCardToday);
}

final aiProactiveSuggestionCoordinatorProvider =
    Provider<AiProactiveSuggestionCoordinator>((ref) {
      return AiProactiveSuggestionCoordinator(
        repository: ref.read(aiProactiveSuggestionRepositoryProvider),
        store: ref.read(aiProactiveSuggestionStoreProvider),
        locationService: ref.read(aiCurrentLocationServiceProvider),
      );
    });

final aiProactiveSuggestionProvider = FutureProvider.autoDispose
    .family<AiProactiveSuggestion?, AiProactiveSuggestionRequest>((
      ref,
      request,
    ) {
      return ref
          .read(aiProactiveSuggestionCoordinatorProvider)
          .resolve(request);
    }, retry: (_, _) => null);

class AiProactiveSuggestionCoordinator {
  AiProactiveSuggestionCoordinator({
    required AiProactiveSuggestionRepository repository,
    required AiProactiveSuggestionStore store,
    required AiCurrentLocationService locationService,
  }) : _repository = repository,
       _store = store,
       _locationService = locationService;

  final AiProactiveSuggestionRepository _repository;
  final AiProactiveSuggestionStore _store;
  final AiCurrentLocationService _locationService;
  final Map<String, Future<void>> _resolutionTails = {};
  final Set<String> _dismissedSessionKeys = {};

  Future<AiProactiveSuggestion?> resolve(AiProactiveSuggestionRequest request) {
    final previous = _resolutionTails[request.userId] ?? Future<void>.value();
    final result = previous.then((_) => _resolveNext(request));
    final tail = result.then<void>((_) {}, onError: (_, _) {});
    _resolutionTails[request.userId] = tail;
    tail.whenComplete(() {
      if (identical(_resolutionTails[request.userId], tail)) {
        _resolutionTails.remove(request.userId);
      }
    });
    return result;
  }

  Future<AiProactiveSuggestion?> _resolveNext(
    AiProactiveSuggestionRequest request,
  ) async {
    if (await _hasDismissedInSession(request)) {
      return null;
    }

    final now = DateTime.now();
    final cached = await _loadSuggestion(request.userId);
    if (cached != null &&
        cached.contextDate == request.contextDate &&
        cached.isValid(now: now, currentHasCardToday: request.hasCardToday)) {
      return cached;
    }

    try {
      final location = await _locationService.getCurrentLocation();
      final suggestion = await _repository.generate(location: location);
      if (suggestion.contextDate != request.contextDate ||
          !suggestion.isValid(
            now: DateTime.now(),
            currentHasCardToday: request.hasCardToday,
          )) {
        debugPrint('[ai proactive] discarded a stale generated suggestion');
        return null;
      }
      await _saveSuggestion(request.userId, suggestion);
      return suggestion;
    } on Object catch (error) {
      debugPrint(
        '[ai proactive] suggestion resolution failed: ${_errorReason(error)}',
      );
      return null;
    }
  }

  Future<bool> claimShown(
    AiProactiveSuggestionRequest request,
    AiProactiveSuggestion suggestion,
  ) async {
    try {
      final claimed = await _repository.claimImpression(
        contextDate: suggestion.contextDate,
        sessionId: request.sessionId,
      );
      if (!claimed) {
        debugPrint('[ai proactive] impression claim rejected');
      }
      return claimed;
    } on Object catch (error) {
      debugPrint(
        '[ai proactive] impression claim failed: ${_errorReason(error)}',
      );
      return false;
    }
  }

  Future<void> dismiss(
    AiProactiveSuggestionRequest request,
    AiProactiveSuggestion suggestion,
  ) async {
    _dismissedSessionKeys.add(_sessionKey(request));
    try {
      await _store.markDismissed(
        userId: request.userId,
        sessionId: request.sessionId,
        contextDate: suggestion.contextDate,
      );
    } on Object catch (error) {
      debugPrint(
        '[ai proactive] dismissal persistence failed: ${error.runtimeType}',
      );
      return;
    }
  }

  Future<AiProactiveSuggestion?> _loadSuggestion(String userId) async {
    try {
      return await _store.loadSuggestion(userId);
    } on Object {
      return null;
    }
  }

  Future<bool> _hasDismissedInSession(
    AiProactiveSuggestionRequest request,
  ) async {
    final key = _sessionKey(request);
    if (_dismissedSessionKeys.contains(key)) {
      return true;
    }
    try {
      final dismissed = await _store.hasDismissedInSession(
        userId: request.userId,
        sessionId: request.sessionId,
        contextDate: request.contextDate,
      );
      if (dismissed) {
        _dismissedSessionKeys.add(key);
      }
      return dismissed;
    } on Object {
      return false;
    }
  }

  String _sessionKey(AiProactiveSuggestionRequest request) {
    return '${request.userId}:${request.contextDate}:${request.sessionId}';
  }

  Future<void> _saveSuggestion(
    String userId,
    AiProactiveSuggestion suggestion,
  ) async {
    try {
      await _store.saveSuggestion(userId, suggestion);
    } on Object {
      return;
    }
  }
}

String _errorReason(Object error) {
  return error is AiProactiveSuggestionException
      ? error.reason.name
      : error.runtimeType.toString();
}
