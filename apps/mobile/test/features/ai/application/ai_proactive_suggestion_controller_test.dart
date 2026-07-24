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
      await coordinator.markShown(firstRequest, first!);
      final second = await coordinator.resolve(firstRequest);

      expect(second, isNull);
    },
  );

  test('falls back silently when generation fails', () async {
    final coordinator = AiProactiveSuggestionCoordinator(
      repository: _FakeSuggestionRepository(shouldFail: true),
      store: _FakeSuggestionStore(),
      locationService: _FakeLocationService(),
    );

    expect(await coordinator.resolve(firstRequest), isNull);
  });
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
  });

  final AiProactiveSuggestion? generatedSuggestion;
  final bool shouldFail;
  var generateCount = 0;
  AiCurrentLocation? lastLocation;

  @override
  Future<AiProactiveSuggestion> generate({
    required AiCurrentLocation? location,
  }) async {
    generateCount += 1;
    lastLocation = location;
    if (shouldFail) {
      throw const AiProactiveSuggestionException();
    }
    return generatedSuggestion ?? _suggestion;
  }
}

class _FakeSuggestionStore implements AiProactiveSuggestionStore {
  _FakeSuggestionStore({this.cachedSuggestion});

  AiProactiveSuggestion? cachedSuggestion;
  final Set<String> _shownSessions = {};

  @override
  Future<bool> canShow({
    required String userId,
    required String sessionId,
    required String contextDate,
  }) async {
    return !_shownSessions.contains(sessionId);
  }

  @override
  Future<AiProactiveSuggestion?> loadSuggestion(String userId) async {
    return cachedSuggestion;
  }

  @override
  Future<void> markShown({
    required String userId,
    required String sessionId,
    required String contextDate,
  }) async {
    _shownSessions.add(sessionId);
  }

  @override
  Future<void> saveSuggestion(
    String userId,
    AiProactiveSuggestion suggestion,
  ) async {
    cachedSuggestion = suggestion;
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
