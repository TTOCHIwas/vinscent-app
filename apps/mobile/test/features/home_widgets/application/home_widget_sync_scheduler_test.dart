import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home_widgets/application/home_widget_sync_scheduler.dart';

void main() {
  testWidgets('debounces repeated synchronization requests', (tester) async {
    var synchronizationCount = 0;
    final scheduler = HomeWidgetSyncScheduler(
      synchronize: () async {
        synchronizationCount += 1;
      },
    );
    addTearDown(scheduler.dispose);

    scheduler.schedule();
    scheduler.schedule();
    scheduler.schedule();

    await tester.pump(const Duration(milliseconds: 349));
    expect(synchronizationCount, 0);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(synchronizationCount, 1);
  });

  testWidgets('runs one queued synchronization after the active run', (
    tester,
  ) async {
    final firstRunBarrier = Completer<void>();
    var synchronizationCount = 0;
    final scheduler = HomeWidgetSyncScheduler(
      synchronize: () async {
        synchronizationCount += 1;
        if (synchronizationCount == 1) {
          await firstRunBarrier.future;
        }
      },
    );
    addTearDown(scheduler.dispose);

    scheduler.schedule();
    await tester.pump(const Duration(milliseconds: 350));
    expect(synchronizationCount, 1);

    scheduler.schedule();
    await tester.pump(const Duration(milliseconds: 350));
    expect(synchronizationCount, 1);

    firstRunBarrier.complete();
    await tester.pump();
    await tester.pump();
    expect(synchronizationCount, 2);
  });

  testWidgets('dispose cancels a pending synchronization', (tester) async {
    var synchronizationCount = 0;
    final scheduler = HomeWidgetSyncScheduler(
      synchronize: () async {
        synchronizationCount += 1;
      },
    );

    scheduler.schedule();
    scheduler.dispose();
    await tester.pump(const Duration(milliseconds: 350));

    expect(synchronizationCount, 0);
  });
}
