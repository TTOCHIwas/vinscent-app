import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event_repository.dart';
import 'package:vinscent/features/calendar/data/couple_member_birthday.dart';
import 'package:vinscent/features/calendar/data/couple_member_birthday_repository.dart';
import 'package:vinscent/features/characters/data/couple_character.dart';
import 'package:vinscent/features/characters/data/couple_character_repository.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_partner_card_repository.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_snapshot.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_snapshot_repository.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';
import 'package:vinscent/features/recordings/data/couple_recording_repository.dart';

void main() {
  test(
    'preserves only the source that failed while updating other assets',
    () async {
      final updatedAt = DateTime.utc(2026, 7, 22);
      final loader = HomeWidgetSnapshotAssetLoader(
        characterRepository: _CharacterRepository(
          CoupleCharacter(
            coupleId: 'couple-id',
            imagePath: 'character.png',
            drawingDataPath: 'character.json',
            imageUrl: 'https://example.com/character.png',
            createdAt: updatedAt,
            updatedAt: updatedAt,
          ),
        ),
        recordingRepository: _FailingRecordingRepository(),
        calendarEventRepository: _CalendarEventRepository(),
        memberBirthdayRepository: const _BirthdayRepository([]),
        partnerCardRepository: _PartnerCardRepository(
          HomeWidgetPartnerCard(
            id: 'card-id',
            previewUrl: 'https://example.com/card.png',
            revision: 2,
            updatedAt: updatedAt,
          ),
        ),
      );

      final snapshot = await loader.fetch(
        coupleId: 'couple-id',
        currentUserId: 'user-id',
        relationshipStartDate: DateTime(2026, 7, 22),
        currentDate: DateTime(2026, 7, 22),
      );

      expect(snapshot.characterImage.type, HomeWidgetAssetUpdateType.replace);
      expect(snapshot.recordingAudio.type, HomeWidgetAssetUpdateType.preserve);
      expect(snapshot.partnerCardImage.type, HomeWidgetAssetUpdateType.replace);
      expect(
        snapshot.calendarSummary.type,
        HomeWidgetCalendarSummaryUpdateType.replace,
      );
      expect(snapshot.calendarSummary.summary?.title, '첫날');
      expect(snapshot.requiresRetry, isTrue);
    },
  );

  test('preserves the calendar summary when its source fails', () async {
    final loader = HomeWidgetSnapshotAssetLoader(
      characterRepository: _CharacterRepository(null),
      recordingRepository: _RecordingRepository(),
      calendarEventRepository: _FailingCalendarEventRepository(),
      memberBirthdayRepository: const _BirthdayRepository([]),
      partnerCardRepository: const _PartnerCardRepository(null),
    );

    final snapshot = await loader.fetch(
      coupleId: 'couple-id',
      currentUserId: 'user-id',
      relationshipStartDate: DateTime(2026, 7, 22),
      currentDate: DateTime(2026, 7, 26),
    );

    expect(
      snapshot.calendarSummary.type,
      HomeWidgetCalendarSummaryUpdateType.preserve,
    );
    expect(snapshot.characterImage.type, HomeWidgetAssetUpdateType.remove);
    expect(snapshot.recordingAudio.type, HomeWidgetAssetUpdateType.remove);
    expect(snapshot.partnerCardImage.type, HomeWidgetAssetUpdateType.remove);
    expect(snapshot.requiresRetry, isTrue);
  });

  test('includes a member birthday in the character widget summary', () async {
    final loader = HomeWidgetSnapshotAssetLoader(
      characterRepository: _CharacterRepository(null),
      recordingRepository: _RecordingRepository(),
      calendarEventRepository: _CalendarEventRepository(),
      memberBirthdayRepository: _BirthdayRepository([
        CoupleMemberBirthday(
          role: CoupleMemberRole.self,
          displayName: '또치',
          birthDate: DateTime(1990, 7, 28),
        ),
      ]),
      partnerCardRepository: const _PartnerCardRepository(null),
    );

    final snapshot = await loader.fetch(
      coupleId: 'couple-id',
      currentUserId: 'user-id',
      relationshipStartDate: DateTime(2026, 1, 1),
      currentDate: DateTime(2026, 7, 28),
    );

    expect(snapshot.calendarSummary.summary?.title, '내 생일');
  });
}

class _CharacterRepository extends Fake implements CoupleCharacterRepository {
  _CharacterRepository(this.character);

  final CoupleCharacter? character;

  @override
  Future<CoupleCharacter?> fetchCurrentCharacter() async => character;
}

class _FailingRecordingRepository extends Fake
    implements CoupleRecordingRepository {
  @override
  Future<CoupleRecordingOverview> fetchOverview() {
    throw StateError('temporary recording failure');
  }
}

class _RecordingRepository extends Fake implements CoupleRecordingRepository {
  @override
  Future<CoupleRecordingOverview> fetchOverview() async {
    return const CoupleRecordingOverview(
      slotLimit: 0,
      currentRecording: null,
      savedSlots: [],
    );
  }
}

class _PartnerCardRepository implements HomeWidgetPartnerCardRepository {
  const _PartnerCardRepository(this.card);

  final HomeWidgetPartnerCard? card;

  @override
  Future<HomeWidgetPartnerCard?> fetchLatestPartnerCard({
    required String coupleId,
    required String currentUserId,
  }) async {
    return card;
  }
}

class _CalendarEventRepository extends Fake
    implements CoupleCalendarEventRepository {
  @override
  Future<List<CoupleCalendarEvent>> fetchOccurrences({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return const [];
  }
}

class _FailingCalendarEventRepository extends Fake
    implements CoupleCalendarEventRepository {
  @override
  Future<List<CoupleCalendarEvent>> fetchOccurrences({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    throw StateError('temporary calendar failure');
  }
}

class _BirthdayRepository implements CoupleMemberBirthdayRepository {
  const _BirthdayRepository(this.birthdays);

  final List<CoupleMemberBirthday> birthdays;

  @override
  Future<List<CoupleMemberBirthday>> fetchActiveCoupleBirthdays() async {
    return birthdays;
  }
}
