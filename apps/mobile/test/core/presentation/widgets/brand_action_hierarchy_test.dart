import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_action_button.dart';
import 'package:vinscent/core/presentation/widgets/app_action_tone.dart';
import 'package:vinscent/core/presentation/widgets/app_loading_indicator.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/shell/presentation/widgets/app_bottom_bar.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_editor_header.dart';

void main() {
  testWidgets('primary actions use the vivid coral with white content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppActionButton(
            label: 'Save',
            enabled: true,
            tone: AppActionTone.brand,
            onPressed: () {},
          ),
        ),
      ),
    );
    final surface = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppActionButton),
        matching: find.byType(Material),
      ),
    );
    expect(surface.color, const Color(0xFFF05A47));
    expect(tester.widget<Text>(find.text('Save')).style?.color, Colors.white);
  });

  for (final location in ['/home', '/calendar', '/ai']) {
    testWidgets('dock stays monochrome on $location', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomBar(
              height: 90,
              currentLocation: location,
              onHomePressed: () {},
              onCalendarPressed: () {},
              onAiPressed: () {},
            ),
          ),
        ),
      );
      final icons = tester.widgetList<Icon>(
        find.descendant(
          of: find.byType(AppBottomBar),
          matching: find.byType(Icon),
        ),
      );
      expect(icons.where((icon) => icon.color == Colors.black), hasLength(1));
      expect(
        icons.where((icon) => icon.color == AppColors.shellBottomBarIconIdle),
        hasLength(2),
      );
      expect(icons.any((icon) => icon.color == AppColors.brandAction), isFalse);
    });
  }

  testWidgets('general loading does not use the action accent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: AppLoadingIndicator())),
    );
    expect(
      tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      ).color,
      AppColors.textMuted,
    );
  });

  testWidgets('card publishing is accented without changing other tools', (
    tester,
  ) async {
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryCardEditorHeader(
            canSave: true,
            isSaving: false,
            canDelete: true,
            onBackPressed: () {},
            onDeletePressed: () {},
            onSavePressed: () => saves++,
          ),
        ),
      ),
    );
    final save = find.byKey(const ValueKey('story-card-editor-save'));
    expect(tester.widget<IconButton>(save).color, AppColors.brandAction);
    expect(
      tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      ).color,
      Colors.white,
    );
    expect(
      tester.widget<IconButton>(save).style?.backgroundColor?.resolve({}) ??
          Colors.transparent,
      Colors.transparent,
    );
    await tester.tap(save);
    expect(saves, 1);
  });

  testWidgets('card publishing keeps its disabled and loading behavior', (
    tester,
  ) async {
    for (final isSaving in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoryCardEditorHeader(
              canSave: false,
              isSaving: isSaving,
              canDelete: false,
              onBackPressed: () {},
              onDeletePressed: () {},
              onSavePressed: () => fail('Disabled save must not run'),
            ),
          ),
        ),
      );
      final save = tester.widget<IconButton>(
        find.byKey(const ValueKey('story-card-editor-save')),
      );
      expect(save.onPressed, isNull);
      expect(save.disabledColor, Colors.white38);
      if (isSaving) {
        expect(
          tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          ).color,
          AppColors.brandAction,
        );
      }
    }
  });
}
