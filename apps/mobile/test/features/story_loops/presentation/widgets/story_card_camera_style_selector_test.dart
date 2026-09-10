import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_camera_effect.dart';
import 'package:vinscent/features/story_loops/data/story_card_film_look.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_camera_style_selector.dart';

void main() {
  testWidgets('필름과 캐릭터 효과를 서로 독립적으로 선택한다', (tester) async {
    var film = StoryCardFilmLook.original;
    var effect = StoryCardCameraEffect.none;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: StoryCardCameraStyleSelector(
                selectedFilmLook: film,
                selectedEffect: effect,
                isEffectLoading: false,
                onFilmLookChanged: (value) => setState(() => film = value),
                onEffectChanged: (value) => setState(() => effect = value),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('온기'));
    await tester.pump();
    expect(film, StoryCardFilmLook.warmth);
    expect(effect, StoryCardCameraEffect.none);

    await tester.tap(find.byKey(const ValueKey('story-card-style-effect-tab')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('story-card-camera-effect-couple-character')),
    );
    await tester.pump();

    expect(film, StoryCardFilmLook.warmth);
    expect(effect, StoryCardCameraEffect.coupleCharacter);
  });
}
