import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/application/ai_current_location_service.dart';
import 'package:vinscent/features/ai/application/ai_proactive_suggestion_controller.dart';
import 'package:vinscent/features/ai/data/ai_proactive_suggestion.dart';
import 'package:vinscent/features/ai/data/ai_proactive_suggestion_repository.dart';
import 'package:vinscent/features/ai/data/ai_proactive_suggestion_store.dart';

void main() {
  const firstRequest = AiProactiveSuggestionRequest(
    userId: 'user-1',
    sessionId: 'session-1',
    hasCardToday: false,
  );

  test(
    'reuses a valid cached suggestion without requesting location',
    () async {
      final store = _FakeSuggestionStore(cachedSuggestion: _suggestion);
      final repository = _FakeSuggestionRepository();
      final location = _FakeLocationService();
      final coordinator = AiProactiveSuggestionCoordinator(
        repository: repository,
        store: store,
        locationService: location,
      );

      final result = await coordinator.resolve(firstRequest);

      expect(result, same(_suggestion));
      expect(repository.generateCount, 0);
      expect(location.requestCount, 0);
    },
  );

  test('regenerates when the current card state changed', () async {
    final store = _FakeSuggestionStore(cachedSuggestion: _suggestion);
    final repository = _FakeSuggestionRepository(
      generatedSuggestion: _suggestionWithCard,
    );
    final location = _FakeLocationService(
      currentLocation: const AiCurrentLocation(latitude: 37.5, longitude: 127),
    );
    final coordinator = AiProactiveSuggestionCoordinator(
      repository: repository,
      store: store,
      locationService: location,
    );

    final result = await coordinator.resolve(
      const AiProactiveSuggestionRequest(
        userId: 'user-1',
        sessionId: 'session-1',
        hasCardToday: true,
      ),
    );

    expect(result, same(_suggestionWithCard));
    expect(repository.generateCount, 1);
    expect(location.requestCount, 1);
    expect(repository.lastLocation?.latitude, 37.5);
    expect(store.cachedSuggestion, same(_suggestionWithCard));
  });

  test(
    'does not return a suggestion twice in the same foreground session',
    () async {
      final store = _FakeSuggestionStore(cachedSuggestion: _suggestion);
      final coordinator = AiProactiveSuggestionCoordinator(
        repository: _FakeSuggestionRepository(),
        store: store,
        locationService: _FakeLocationService(),
      );

      final first = await coordinator.resolve(firstRequest);
      expect(await coordinator.claimShown(firstRequest, first!), true);
      final second = await coordinator.resolve(firstRequest);

      expect(second, isNull);
    },
  );

  test('does not let legacy local daily history block a new session', () async {
    final store = SharedPreferencesAiProactiveSuggestionStore(
      preferences: _MemoryPreferences(),
    );
    for (var index = 1; index <= 3; index++) {
      await store.markShown(
        userId: 'user-1',
        sessionId: 'legacy-session-$index',
        contextDate: _suggestion.contextDate,
      );
    }
    await store.saveSuggestion('user-1', _suggestion);
    final repository = _FakeSuggestionRepository();
    final coordinator = AiProactiveSuggestionCoordinator(
      repository: repository,
      store: store,
      locationService: _FakeLocationService(),
    );

    final suggestion = await coordinator.resolve(
      const AiProactiveSuggestionRequest(
        userId: 'user-1',
        sessionId: 'session-after-migration',
        hasCardToday: false,
      ),
    );

    expect(suggestion?.id, _suggestion.id);
    expect(repository.generateCount, 0);
    expect(
      await coordinator.claimShown(
        const AiProactiveSuggestionRequest(
          userId: 'user-1',
          sessionId: 'session-after-migration',
          hasCardToday: false,
        ),
        suggestion!,
      ),
      isTrue,
    );
  });

  test('falls back silently when generation fails', () async {
    final coordinator = AiProactiveSuggestionCoordinator(
      repository: _FakeSuggestionRepository(shouldFail: true),
      store: _FakeSuggestionStore(),
      locationService: _FakeLocationService(),
    );

    expect(await coordinator.resolve(firstRequest), isNull);
  });

  test('generates when the local suggestion cache cannot be read', () async {
    final repository = _FakeSuggestionRepository();
    final coordinator = AiProactiveSuggestionCoordinator(
      repository: repository,
      store: _FakeSuggestionStore(failLoadSuggestion: true),
      locationService: _FakeLocationService(),
    );

    expect(await coordinator.resolve(firstRequest), same(_suggestion));
    expect(repository.generateCount, 1);
  });

  test('generates when the local session record cannot be read', () async {
    final repository = _FakeSuggestionRepository();
    final coordinator = AiProactiveSuggestionCoordinator(
      repository: repository,
      store: _FakeSuggestionStore(failHasShownInSession: true),
      locationService: _FakeLocationService(),
    );

    expect(await coordinator.resolve(firstRequest), same(_suggestion));
    expect(repository.generateCount, 1);
  });

  test('returns a generated suggestion when local caching fails', () async {
    final coordinator = AiProactiveSuggestionCoordinator(
      repository: _FakeSuggestionRepository(),
      store: _FakeSuggestionStore(failSaveSuggestion: true),
      locationService: _FakeLocationService(),
    );

    expect(await coordinator.resolve(firstRequest), same(_suggestion));
  });

  test('defers to the remote claim when local display checks fail', () async {
    final coordinator = AiProactiveSuggestionCoordinator(
      repository: _FakeSuggestionRepository(),
      store: _FakeSuggestionStore(
        cachedSuggestion: _suggestion,
        failHasShownInSession: true,
      ),
      locationService: _FakeLocationService(),
    );

    expect(await coordinator.resolve(firstRequest), same(_suggestion));
  });

  test(
    'does not mark a suggestion shown when the account quota rejects it',
    () async {
      final store = _FakeSuggestionStore(cachedSuggestion: _suggestion);
      final repository = _FakeSuggestionRepository(claimAllowed: false);
      final coordinator = AiProactiveSuggestionCoordinator(
        repository: repository,
        store: store,
        locationService: _FakeLocationService(),
      );

      expect(await coordinator.claimShown(firstRequest, _suggestion), false);
      expect(store.markShownCount, 0);
      expect(repository.claimCount, 1);
    },
  );

  test(
    'shows a remotely claimed suggestion when local tracking fails',
    () async {
      final store = _FakeSuggestionStore(
        cachedSuggestion: _suggestion,
        failMarkShown: true,
      );
      final coordinator = AiProactiveSuggestionCoordinator(
        repository: _FakeSuggestionRepository(),
        store: store,
        locationService: _FakeLocationService(),
      );

      expect(await coordinator.claimShown(firstRequest, _suggestion), true);
      expect(store.markShownCount, 1);
    },
  );

  test(
    'does not cache a generated suggestion for a stale card state',
    () async {
      final store = _FakeSuggestionStore();
      final repository = _FakeSuggestionRepository(
        generatedSuggestion: _suggestionWithCard,
      );
      final coordinator = AiProactiveSuggestionCoordinator(
        repository: repository,
        store: store,
        locationService: _FakeLocationService(),
      );

      expect(await coordinator.resolve(firstRequest), isNull);
      expect(store.cachedSuggestion, isNull);
    },
  );

  test('serializes overlapping generations for the same user', () async {
    final gate = Completer<void>();
    final store = _FakeSuggestionStore();
    final repository = _FakeSuggestionRepository(generationGate: gate);
    final coordinator = AiProactiveSuggestionCoordinator(
      repository: repository,
      store: store,
      locationService: _FakeLocationService(),
    );

    final first = coordinator.resolve(firstRequest);
    final second = coordinator.resolve(firstRequest);
    gate.complete();

    expect(await first, same(_suggestion));
    expect(await second, same(_suggestion));
    expect(repository.generateCount, 1);
  });

  test(
    'uses the server context date instead of the device date for a new suggestion',
    () async {
      final serverSuggestion = AiProactiveSuggestion(
        id: 'server-date-suggestion',
        text: _suggestion.text,
        kind: AiProactiveSuggestionKind.dateIdea,
        generatedAt: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(hours: 1)),
        contextDate: '2099-01-01',
        hasCardToday: false,
      );
      final repository = _FakeSuggestionRepository(
        generatedSuggestion: serverSuggestion,
      );
      final coordinator = AiProactiveSuggestionCoordinator(
        repository: repository,
        store: _FakeSuggestionStore(),
        locationService: _FakeLocationService(),
      );

      final result = await coordinator.resolve(firstRequest);

      expect(result, same(serverSuggestion));
      expect(repository.generateCount, 1);
      expect(await coordinator.claimShown(firstRequest, result!), isTrue);
      expect(repository.lastClaimContextDate, '2099-01-01');
    },
  );
}

final _suggestion = AiProactiveSuggestion(
  id: 'suggestion-1',
  text: '하늘이 괜찮아 보이면 가볍게 걸으며 사진을 한 장 남겨도 예쁘겠다',
  kind: AiProactiveSuggestionKind.dateIdea,
  generatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
  validUntil: DateTime.now().add(const Duration(hours: 1)),
  contextDate: _today(),
  hasCardToday: false,
);

final _suggestionWithCard = AiProactiveSuggestion(
  id: 'suggestion-2',
  text: '카드는 이미 남겼으니 오늘은 둘이 천천히 산책하는 건 어때?',
  kind: AiProactiveSuggestionKind.dateIdea,
  generatedAt: DateTime.now(),
  validUntil: DateTime.now().add(const Duration(hours: 1)),
  contextDate: _today(),
  hasCardToday: true,
);

String _today() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

class _FakeSuggestionRepository implements AiProactiveSuggestionRepository {
  _FakeSuggestionRepository({
    this.generatedSuggestion,
    this.shouldFail = false,
    this.claimAllowed = true,
    this.generationGate,
  });

  final AiProactiveSuggestion? generatedSuggestion;
  final bool shouldFail;
  final bool claimAllowed;
  final Completer<void>? generationGate;
  var generateCount = 0;
  var claimCount = 0;
  AiCurrentLocation? lastLocation;
  String? lastClaimContextDate;

  @override
  Future<AiProactiveSuggestion> generate({
    required AiCurrentLocation? location,
  }) async {
    generateCount += 1;
    lastLocation = location;
    await generationGate?.future;
    if (shouldFail) {
      throw const AiProactiveSuggestionException();
    }
    return generatedSuggestion ?? _suggestion;
  }

  @override
  Future<bool> claimImpression({
    required String contextDate,
    required String sessionId,
  }) async {
    claimCount += 1;
    lastClaimContextDate = contextDate;
    return claimAllowed;
  }
}

class _FakeSuggestionStore implements AiProactiveSuggestionStore {
  _FakeSuggestionStore({
    this.cachedSuggestion,
    this.failMarkShown = false,
    this.failLoadSuggestion = false,
    this.failHasShownInSession = false,
    this.failSaveSuggestion = false,
  });

  AiProactiveSuggestion? cachedSuggestion;
  final bool failMarkShown;
  final bool failLoadSuggestion;
  final bool failHasShownInSession;
  final bool failSaveSuggestion;
  final Set<String> _shownSessions = {};
  var markShownCount = 0;

  @override
  Future<bool> hasShownInSession({
    required String userId,
    required String sessionId,
  }) async {
    if (failHasShownInSession) {
      throw StateError('local storage unavailable');
    }
    return _shownSessions.contains(sessionId);
  }

  @override
  Future<AiProactiveSuggestion?> loadSuggestion(String userId) async {
    if (failLoadSuggestion) {
      throw StateError('local storage unavailable');
    }
    return cachedSuggestion;
  }

  @override
  Future<void> markShown({
    required String userId,
    required String sessionId,
    required String contextDate,
  }) async {
    markShownCount += 1;
    if (failMarkShown) {
      throw StateError('local storage unavailable');
    }
    _shownSessions.add(sessionId);
  }

  @override
  Future<void> saveSuggestion(
    String userId,
    AiProactiveSuggestion suggestion,
  ) async {
    if (failSaveSuggestion) {
      throw StateError('local storage unavailable');
    }
    cachedSuggestion = suggestion;
  }
}

class _MemoryPreferences implements AiProactiveSuggestionPreferences {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _FakeLocationService implements AiCurrentLocationService {
  _FakeLocationService({this.currentLocation});

  final AiCurrentLocation? currentLocation;
  var requestCount = 0;

  @override
  Future<AiCurrentLocation?> getCurrentLocation() async {
    requestCount += 1;
    return currentLocation;
  }
}
