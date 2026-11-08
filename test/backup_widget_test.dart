import 'dart:io';

import 'package:boulder_notes/local_log.dart';
import 'package:boulder_notes/main.dart';
import 'package:boulder_notes/session_log.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('backup actions render and dialog cancels cleanly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final log = SessionLog(LocalLogStore(File('unused.json')));
    log.data = LocalLog(
      gyms: [const Gym('g', 'The Foundry')],
      sessions: [],
      routes: [],
      attempts: [],
      notes: [],
      resets: [],
    );

    await tester.pumpWidget(
      BoulderNotesApp(platform: TargetPlatform.android, initialLog: log),
    );
    await tester.pump();

    expect(find.text('Export backup ZIP'), findsOneWidget);
    expect(find.text('Import backup ZIP'), findsOneWidget);
    expect(find.text('Delete all local data'), findsOneWidget);

    await tester.tap(find.text('Delete all local data'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Delete all local data and photos?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Delete all local data and photos?'),
      findsNothing,
    );
    expect(find.textContaining('The Foundry'), findsOneWidget);
  });

  testWidgets('iOS uses Cupertino dialog confirmation for wipe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final log = SessionLog(LocalLogStore(File('unused.json')));
    log.data = LocalLog(
      gyms: [const Gym('g', 'Sender Studio')],
      sessions: [],
      routes: [],
      attempts: [],
      notes: [],
      resets: [],
    );

    await tester.pumpWidget(
      BoulderNotesApp(platform: TargetPlatform.iOS, initialLog: log),
    );
    await tester.pump();

    await tester.tap(find.text('Delete all local data'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.textContaining('Sender Studio'), findsOneWidget);
  });
}
