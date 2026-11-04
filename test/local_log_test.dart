import 'dart:convert';
import 'dart:io';

import 'package:boulder_notes/local_log.dart';
import 'package:boulder_notes/session_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sample = LocalLog(
    gyms: [const Gym('g1', 'North Wall'), const Gym('g2', 'South Wall')],
    sessions: [
      const ClimbingSession('s1', 'g1', '2026-10-01'),
      const ClimbingSession('s2', 'g1', '2026-11-01'),
    ],
    resets: [const GymReset('reset1', 'g1', '2026-10-15')],
    routes: [
      const ClimbRoute(
        'r1',
        'g1',
        'Blue slab',
        GradeSystem.vScale,
        'V3',
        archivedAt: '2026-10-15',
        resetId: 'reset1',
      ),
      const ClimbRoute('r2', 'g1', 'New blue slab', GradeSystem.font, '6A'),
    ],
    attempts: [
      const Attempt('a1', 's1', 'r1', AttemptResult.fail, '2026-10-01'),
      const Attempt('a2', 's2', 'r2', AttemptResult.flash, '2026-11-01'),
    ],
    notes: [const BetaNote('n1', 'r1', 'Left toe hook')],
  );

  test('round-trip retains archived route, reset, attempts and beta across sessions', () {
    final decoded = LocalLog.fromJson(
      jsonDecode(jsonEncode(sample.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.toJson(), sample.toJson());
    expect(decoded.routes.first.archivedAt, '2026-10-15');
    expect(decoded.attempts.first.routeId, 'r1');
    expect(decoded.attempts.last.routeId, 'r2');
    expect(decoded.notes.single.text, 'Left toe hook');
    expect(AttemptResult.values.map((e) => e.name), [
      'flash',
      'send',
      'fail',
      'repeat',
      'project',
    ]);
    expect(GradeSystem.values.map((e) => e.name), [
      'vScale',
      'font',
      'gymColor',
    ]);
  });

  test('migrates version 1 to version 2 without changing old history', () {
    final old = sample.toJson();
    old['schema'] = 1;
    old.remove('resets');
    final routes = old['routes'] as List;
    for (final route in routes) {
      (route as Map).remove('archivedAt');
      route.remove('resetId');
    }
    final migrated = LocalLog.fromJson(
      jsonDecode(jsonEncode(old)) as Map<String, dynamic>,
    );
    expect(migrated.toJson()['schema'], logSchema);
    expect(migrated.resets, isEmpty);
    expect(migrated.attempts.length, 2);
    expect(migrated.routes.first.archivedAt, isNull);
  });

  test(
    'rejects future schema, malformed records, duplicate and orphan references',
    () {
      final future = sample.toJson()..['schema'] = 4;
      expect(() => LocalLog.fromJson(future), throwsFormatException);
      final malformed = sample.toJson()..['attempts'] = [23];
      expect(() => LocalLog.fromJson(malformed), throwsFormatException);
      final duplicate = sample.toJson()
        ..['notes'] = [const BetaNote('r1', 'r1', 'Oops').toJson()];
      expect(() => LocalLog.fromJson(duplicate), throwsFormatException);
      final crossGym = sample.toJson()
        ..['attempts'] = [
          const Attempt(
            'x',
            's1',
            'r2',
            AttemptResult.fail,
            '2026-11-01',
          ).toJson(),
        ];
      // Same gym is valid; introduce route from different gym.
      (crossGym['routes'] as List).add(
        const ClimbRoute(
          'other',
          'g2',
          'Purple',
          GradeSystem.gymColor,
          'Purple',
        ).toJson(),
      );
      crossGym['attempts'] = [
        const Attempt(
          'x',
          's1',
          'other',
          AttemptResult.fail,
          '2026-11-01',
        ).toJson(),
      ];
      expect(() => LocalLog.fromJson(crossGym), throwsFormatException);
      final missingReset = sample.toJson();
      (missingReset['routes'] as List).first['resetId'] = 'unknown';
      expect(() => LocalLog.fromJson(missingReset), throwsFormatException);
    },
  );

  test('resetGym archives active routes and keeps past session history', () {
    final afterReset = sample.resetGym(
      const GymReset('reset2', 'g1', '2026-11-15'),
    );
    expect(afterReset.resets.length, 2);
    final route = afterReset.routes.firstWhere((r) => r.id == 'r2');
    expect(route.archivedAt, '2026-11-15');
    expect(route.resetId, 'reset2');
    expect(afterReset.attempts.length, sample.attempts.length);
    expect(afterReset.sessions.length, sample.sessions.length);
  });

  test(
    'failed save preserves last valid file and cleans temporary files',
    () async {
      final dir = await Directory.systemTemp.createTemp('boulder-log-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/log.json');
      final store = LocalLogStore(file);
      await store.save(sample);
      final prior = await file.readAsBytes();
      expect((await store.load()).toJson(), sample.toJson());
      final broken = sample.toJson()
        ..['notes'] = [const BetaNote('bad', 'missing', 'Oops').toJson()];
      expect(
        () => store.save(LocalLog.fromJson(broken)),
        throwsFormatException,
      );
      expect(await file.readAsBytes(), prior);
      expect(await dir.list().length, 1);
      await file.writeAsString('{broken');
      await expectLater(store.load(), throwsFormatException);
    },
  );

  test(
    'SessionLog supports session, route, attempt, beta and photo attachments',
    () async {
      final dir = await Directory.systemTemp.createTemp('boulder-session-');
      addTearDown(() => dir.delete(recursive: true));
      final store = LocalLogStore(File('${dir.path}/log.json'));
      final log = SessionLog(store);
      await log.addGym('The Foundry');
      final gymId = log.data.gyms.single.id;
      await log.addSession(gymId, notes: 'Morning power endurance');
      final sessionId = log.data.sessions.single.id;
      await log.addRoute(
        gymId,
        'Pink roof crimp',
        grade: 'V5',
        wall: 'Cave',
        color: 'Pink',
      );
      final routeId = log.data.routes.single.id;
      await log.attempt(
        sessionId,
        routeId,
        AttemptResult.fail,
        verdict: 'Hard V5',
      );
      await log.attempt(
        sessionId,
        routeId,
        AttemptResult.send,
        verdict: 'Soft V5',
      );
      await log.addNote(routeId, 'Heel hook before big reach');
      await log.attachPhoto(routeId, [137, 80, 78, 71, 13, 10, 26, 10, 1]);
      expect(log.data.routes.single.photoPath, endsWith('.png'));
      await expectLater(
        log.attachPhoto(routeId, [1, 2, 3, 4]),
        throwsFormatException,
      );
      expect(log.data.routes.single.photoPath, endsWith('.png'));

      final reloaded = SessionLog(store);
      await reloaded.load();
      expect(reloaded.data.gyms.single.name, 'The Foundry');
      expect(reloaded.data.sessions.single.notes, 'Morning power endurance');
      expect(reloaded.data.routes.single.wallSection, 'Cave');
      expect(reloaded.data.routes.single.photoPath, startsWith('photos/'));
      expect(reloaded.history(routeId).length, 2);
      expect(reloaded.history(routeId).first.verdict, 'Hard V5');
      expect(reloaded.history(routeId).last.result, AttemptResult.send);
      expect(reloaded.data.notes.single.text, 'Heel hook before big reach');
      expect(
        File('${dir.path}/${reloaded.data.routes.single.photoPath!}')
            .existsSync(),
        isTrue,
      );

      await reloaded.archive(routeId);
      expect(reloaded.data.routes.single.archivedAt, isNotNull);
      expect(
        () => reloaded.attempt(sessionId, routeId, AttemptResult.flash),
        throwsStateError,
      );
    },
  );
}
