import 'dart:io';

import 'package:boulder_notes/local_log.dart';
import 'package:boulder_notes/main.dart';
import 'package:boulder_notes/session_log.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.windows,
  ]) {
    testWidgets(
      '$platform boots with native shell at phone/tablet/desktop widths',
      (tester) async {
        final store = LocalLogStore(File('unused-widget-log.json'));
        final preloaded = SessionLog(store);
        for (final width in [390.0, 900.0, 1440.0]) {
          tester.view.physicalSize = Size(width, 850);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            BoulderNotesApp(platform: platform, initialLog: preloaded),
          );
          await tester.pump();
          expect(
            find.text('Your climbing log stays on this device.'),
            findsOneWidget,
          );
          if (platform == TargetPlatform.iOS) {
            expect(find.byType(CupertinoApp), findsOneWidget);
            expect(find.byType(MaterialApp), findsNothing);
          } else {
            expect(find.byType(MaterialApp), findsOneWidget);
            expect(find.byType(CupertinoApp), findsNothing);
          }
          expect(tester.takeException(), isNull);
          if (Platform.isLinux) {
            await expectLater(
              find.byType(BoulderWorkspaceLayout),
              matchesGoldenFile(
                'goldens/${platform.name}-${width.toInt()}.png',
              ),
            );
          }
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  }

  testWidgets(
    'BoulderWorkspaceLayout switches between compact stack and split view',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const nav = Text('Nav Pane');
      const detail = Text('Detail Pane');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BoulderWorkspaceLayout(
              navigationPane: nav,
              detailPane: detail,
              showDetail: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nav Pane'), findsOneWidget);
      expect(find.text('Detail Pane'), findsNothing);

      // Switch to showDetail on compact phone
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BoulderWorkspaceLayout(
              navigationPane: nav,
              detailPane: detail,
              showDetail: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Detail Pane'), findsOneWidget);
      expect(find.text('Nav Pane'), findsNothing);

      // Expand to desktop width (1200) -> both panes visible
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BoulderWorkspaceLayout(
              navigationPane: nav,
              detailPane: detail,
              showDetail: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nav Pane'), findsOneWidget);
      expect(find.text('Detail Pane'), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);
    },
  );

  testWidgets('Windows shortcuts focus navigation and detail panes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = LocalLogStore(File('unused-widget-log.json'));
    final preloaded = SessionLog(store);
    await tester.pumpWidget(
      BoulderNotesApp(platform: TargetPlatform.windows, initialLog: preloaded),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.controlLeft,
      platform: 'windows',
    );
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.digit1,
      platform: 'windows',
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.digit1, platform: 'windows');
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.controlLeft,
      platform: 'windows',
    );
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Desktop navigation',
    );

    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.controlLeft,
      platform: 'windows',
    );
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.digit2,
      platform: 'windows',
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.digit2, platform: 'windows');
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.controlLeft,
      platform: 'windows',
    );
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Desktop route detail',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Accessible semantics and scalable text support', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final store = LocalLogStore(File('unused-widget-log.json'));
    final preloaded = SessionLog(store);
    await tester.pumpWidget(
      BoulderNotesApp(platform: TargetPlatform.android, initialLog: preloaded),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Navigation and route catalog'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Route details, attempts, and beta history'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
