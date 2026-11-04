import 'dart:io';

import 'package:boulder_notes/local_log.dart';
import 'package:boulder_notes/main.dart';
import 'package:boulder_notes/session_log.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  }
}
