import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home/application/home_guide.dart';
import 'package:vinscent/features/home/presentation/widgets/home_guide_rotator.dart';

void main() {
  testWidgets('shows each eligible guide once and then releases the space', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeGuideRotator(
          guides: const [
            HomeGuide.card,
            HomeGuide.recording,
            HomeGuide.aiConsent,
          ],
          onGuideTap: (_) {},
          builder: (guide, opacity, onTap) =>
              Text(guide?.message ?? 'idle', key: const Key('visible-guide')),
        ),
      ),
    );

    expect(find.text(HomeGuide.card.message), findsOneWidget);

    await tester.pump(HomeGuideRotator.displayDuration);
    await tester.pump(HomeGuideRotator.fadeDuration);
    expect(find.text(HomeGuide.recording.message), findsOneWidget);

    await tester.pump(HomeGuideRotator.displayDuration);
    await tester.pump(HomeGuideRotator.fadeDuration);
    expect(find.text(HomeGuide.aiConsent.message), findsOneWidget);

    await tester.pump(HomeGuideRotator.displayDuration);
    await tester.pump(HomeGuideRotator.fadeDuration);
    expect(find.text('idle'), findsOneWidget);
  });

  testWidgets('reports the selected guide and advances immediately', (
    tester,
  ) async {
    HomeGuide? selectedGuide;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeGuideRotator(
          guides: const [HomeGuide.card, HomeGuide.aiConsent],
          onGuideTap: (guide) => selectedGuide = guide,
          builder: (guide, opacity, onTap) => TextButton(
            onPressed: onTap,
            child: Text(guide?.message ?? 'idle'),
          ),
        ),
      ),
    );

    await tester.tap(find.text(HomeGuide.card.message));
    await tester.pump(HomeGuideRotator.fadeDuration);

    expect(selectedGuide, HomeGuide.card);
    expect(find.text(HomeGuide.aiConsent.message), findsOneWidget);
  });

  testWidgets('does not restart when an equivalent guide list rebuilds', (
    tester,
  ) async {
    Widget build() => MaterialApp(
      home: HomeGuideRotator(
        guides: const [HomeGuide.card, HomeGuide.recording],
        onGuideTap: (_) {},
        builder: (guide, opacity, onTap) => Text(guide?.message ?? 'idle'),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pump(HomeGuideRotator.displayDuration);
    await tester.pump(HomeGuideRotator.fadeDuration);
    expect(find.text(HomeGuide.recording.message), findsOneWidget);

    await tester.pumpWidget(build());
    expect(find.text(HomeGuide.recording.message), findsOneWidget);
  });
}
