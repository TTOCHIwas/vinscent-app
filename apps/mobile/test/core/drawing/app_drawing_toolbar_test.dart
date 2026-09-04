import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/drawing/app_drawing.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_toolbar.dart';
import 'package:vinscent/core/presentation/widgets/app_back_button.dart';

void main() {
  testWidgets('keeps exit and save fixed while narrow tools scroll', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var clears = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDrawingToolbar(
            keyPrefix: 'drawing',
            selectedTool: AppDrawingTool.pen,
            isReadOnly: false,
            canUndo: true,
            canClear: true,
            onToolChanged: (_) {},
            onUndoPressed: () {},
            onClearPressed: () => clears++,
            leading: AppBackButton(onPressed: () {}),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.flag_outlined),
                ),
                AppDrawingToolButton(
                  buttonKey: const Key('save'),
                  tooltip: 'Save',
                  icon: const Icon(Icons.check),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final savePosition = tester.getRect(find.byKey(const Key('save')));
    final backPosition = tester.getRect(find.byType(AppBackButton));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawing-clear')));
    expect(clears, 1);
    expect(tester.getRect(find.byKey(const Key('save'))), savePosition);
    expect(tester.getRect(find.byType(AppBackButton)), backPosition);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only state disables drawing actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDrawingToolbar(
            keyPrefix: 'drawing',
            selectedTool: AppDrawingTool.pen,
            isReadOnly: true,
            canUndo: true,
            canClear: true,
            onToolChanged: (_) => fail('read-only tool changed'),
            onUndoPressed: () => fail('read-only undo'),
            onClearPressed: () => fail('read-only clear'),
          ),
        ),
      ),
    );
    for (final tool in ['pen', 'eraser', 'undo', 'clear']) {
      expect(
        tester.widget<IconButton>(find.byKey(Key('drawing-$tool'))).onPressed,
        isNull,
      );
    }
  });
}
