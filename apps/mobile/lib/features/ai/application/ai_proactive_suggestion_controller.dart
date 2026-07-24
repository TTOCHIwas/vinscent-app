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
  const AiProactiveSuggestionCoordinator({
    required AiProactiveSuggestionRepository repository,
    required AiProactiveSuggestionStore store,
    required AiCurrentLocationService locationService,
  }) : _repository = repository,
       _store = store,
       _locationService = locationService;

  final AiProactiveSuggestionRepository _repository;
  final AiProactiveSuggestionStore _store;
  final AiCurrentLocationService _locationService;

  Future<AiProactiveSuggestion?> resolve(
    AiProactiveSuggestionRequest request,
  ) async {
    final now = DateTime.now();
    final cached = await _store.loadSuggestion(request.userId);
    if (cached != null &&
        cached.isValid(now: now, currentHasCardToday: request.hasCardToday)) {
      return await _canShow(request, cached) ? cached : null;
    }

    if (await _store.hasShownInSession(
      userId: request.userId,
      sessionId: request.sessionId,
    )) {
      return null;
    }

    try {
      final location = await _locationService.getCurrentLocation();
      final suggestion = await _repository.generate(location: location);
      await _store.saveSuggestion(request.userId, suggestion);
      return await _canShow(request, suggestion) ? suggestion : null;
    } on Object {
      return null;
    }
  }

  Future<void> markShown(
    AiProactiveSuggestionRequest request,
    AiProactiveSuggestion suggestion,
  ) {
    return _store.markShown(
      userId: request.userId,
      sessionId: request.sessionId,
      contextDate: suggestion.contextDate,
    );
  }

  Future<bool> _canShow(
    AiProactiveSuggestionRequest request,
    AiProactiveSuggestion suggestion,
  ) {
    return _store.canShow(
      userId: request.userId,
      sessionId: request.sessionId,
      contextDate: suggestion.contextDate,
    );
  }
}
