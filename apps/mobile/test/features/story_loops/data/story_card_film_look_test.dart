import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_film_look.dart';

void main() {
  test('film catalog keeps the approved order and labels', () {
    expect(StoryCardFilmLook.values, const [
      StoryCardFilmLook.original,
      StoryCardFilmLook.warmth,
      StoryCardFilmLook.quiet,
      StoryCardFilmLook.color,
      StoryCardFilmLook.moment,
    ]);
    expect(StoryCardFilmLook.values.map((look) => look.label), [
      '원본',
      '온기',
      '고요',
      '컬러',
      '순간',
    ]);
  });

  test('presets encode distinct film characteristics', () {
    expect(StoryCardFilmLook.original.preset.isNeutral, isTrue);
    expect(StoryCardFilmLook.warmth.preset.temperature, greaterThan(0));
    expect(
      StoryCardFilmLook.quiet.preset.exposure,
      lessThan(StoryCardFilmLook.warmth.preset.exposure),
    );
    expect(StoryCardFilmLook.color.preset.saturation, greaterThan(1));
    expect(
      StoryCardFilmLook.moment.preset.grain,
      greaterThan(StoryCardFilmLook.quiet.preset.grain),
    );
    expect(
      StoryCardFilmLook.moment.preset.bloom,
      greaterThan(StoryCardFilmLook.quiet.preset.bloom),
    );
  });

  test('film seed is positive and deterministic for a supplied instant', () {
    final instant = DateTime.utc(2026, 9, 7, 12, 34, 56, 789, 123);

    expect(
      StoryCardFilmSeed.fromDateTime(instant),
      StoryCardFilmSeed.fromDateTime(instant),
    );
    expect(StoryCardFilmSeed.fromDateTime(instant), greaterThan(0));
  });

  test(
    'malformed persisted metadata safely falls back to the original look',
    () {
      expect(
        StoryCardFilmState.fromJson({'look': 7, 'seed': 'not-a-number'}),
        const StoryCardFilmState.original(),
      );
    },
  );
}
