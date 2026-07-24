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
    required this.hasCardToday,
  });

  final String userId;
  final String sessionId;
  final bool hasCardToday;

  @override
  bool operator ==(Object other) {
    return other is AiProactiveSuggestionRequest &&
        other.userId == userId &&
        other.sessionId == sessionId &&
        other.hasCardToday == hasCardToday;
  }

  @override
  int get hashCode => Object.hash(userId, sessionId, hasCardToday);
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
    final now = DateTime.now();
    final cached = await _loadSuggestion(request.userId);
    if (cached != null &&
        cached.isValid(now: now, currentHasCardToday: request.hasCardToday)) {
      return await _hasShownInSession(request) ? null : cached;
    }

    if (await _hasShownInSession(request)) {
      return null;
    }

    try {
      final location = await _locationService.getCurrentLocation();
      final suggestion = await _repository.generate(location: location);
      if (!suggestion.isValid(
        now: DateTime.now(),
        currentHasCardToday: request.hasCardToday,
      )) {
        return null;
      }
      await _saveSuggestion(request.userId, suggestion);
      return suggestion;
    } on Object {
      return null;
    }
  }

  Future<bool> claimShown(
    AiProactiveSuggestionRequest request,
    AiProactiveSuggestion suggestion,
  ) async {
    late final bool claimed;
    try {
      claimed = await _repository.claimImpression(
        contextDate: suggestion.contextDate,
        sessionId: request.sessionId,
      );
    } on Object {
      return false;
    }
    if (!claimed) {
      return false;
    }

    try {
      await _store.markShown(
        userId: request.userId,
        sessionId: request.sessionId,
        contextDate: suggestion.contextDate,
      );
    } on Object {
      return true;
    }
    return true;
  }

  Future<AiProactiveSuggestion?> _loadSuggestion(String userId) async {
    try {
      return await _store.loadSuggestion(userId);
    } on Object {
      return null;
    }
  }

  Future<bool> _hasShownInSession(AiProactiveSuggestionRequest request) async {
    try {
      return await _store.hasShownInSession(
        userId: request.userId,
        sessionId: request.sessionId,
      );
    } on Object {
      return false;
    }
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
