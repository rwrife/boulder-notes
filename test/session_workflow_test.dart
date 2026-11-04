import 'dart:io';

import 'package:boulder_notes/local_log.dart';
import 'package:boulder_notes/main.dart';
import 'package:boulder_notes/session_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('route selection reveals quick attempt controls', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = LocalLogStore(File('unused-widget-log.json'));
    final log = SessionLog(store);
    log.data = LocalLog(
      gyms: [const Gym('g', 'Sender One')],
      sessions: [const ClimbingSession('s', 'g', '2026-11-03')],
      routes: [
        const ClimbRoute('r', 'g', 'Purple roof', GradeSystem.vScale, 'V4'),
      ],
      attempts: [],
      notes: [],
      resets: [],
    );
    await tester.pumpWidget(
      BoulderNotesApp(platform: TargetPlatform.android, initialLog: log),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.textContaining('Purple roof'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.textContaining('Purple roof'));
    await tester.tap(find.textContaining('Purple roof'));
    await tester.pump();
    expect(find.byKey(const Key('history-count')), findsOneWidget);
    expect(find.byKey(const Key('action-Log flash')), findsOneWidget);
    // Persistence transitions run in local_log_test outside widget fake-async.
  });
}
