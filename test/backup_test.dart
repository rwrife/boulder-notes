import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:boulder_notes/backup.dart';
import 'package:boulder_notes/local_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory source;
  late Directory target;
  late LocalLogStore original;
  late LocalLogStore restored;
  final photoPath = 'photos/0123456789abcdef0123456789abcdef.png';
  final png = <int>[137, 80, 78, 71, 13, 10, 26, 10, 1];
  late Uint8List zip;

  setUp(() async {
    source = await Directory.systemTemp.createTemp('boulder-backup-source-');
    target = await Directory.systemTemp.createTemp('boulder-backup-target-');
    original = LocalLogStore(File('${source.path}/log.json'));
    restored = LocalLogStore(File('${target.path}/log.json'));
    await original.save(
      LocalLog(
        gyms: [const Gym('g', 'Gym')],
        sessions: [const ClimbingSession('s', 'g', '2026-11-01')],
        routes: [
          ClimbRoute(
            'r',
            'g',
            'Roof',
            GradeSystem.vScale,
            'V4',
            archivedAt: '2026-11-02',
            photoPath: photoPath,
          ),
        ],
        attempts: [
          const Attempt('a', 's', 'r', AttemptResult.flash, '2026-11-01'),
        ],
        notes: [const BetaNote('n', 'r', 'Left hand first')],
        resets: [],
      ),
    );
    await File('${source.path}/$photoPath').create(recursive: true);
    await File('${source.path}/$photoPath').writeAsBytes(png);
    zip = await LocalBackup(original).export();
  });
  tearDown(() async {
    await source.delete(recursive: true);
    await target.delete(recursive: true);
  });

  test(
    'round trip includes archived history and photos; wipe removes all',
    () async {
      await LocalBackup(restored).import(zip);
      final log = await restored.load();
      expect(log.routes.single.archivedAt, '2026-11-02');
      expect(log.attempts.single.result, AttemptResult.flash);
      expect(log.notes.single.text, 'Left hand first');
      expect(log.routes.single.photoPath, isNot(photoPath));
      expect(
        await File('${target.path}/${log.routes.single.photoPath}')
            .readAsBytes(),
        png,
      );
      await LocalBackup(restored).deleteAll();
      expect(await restored.file.exists(), isFalse);
      expect(await Directory('${target.path}/photos').exists(), isFalse);
    },
  );

  test('malformed, missing, traversing, duplicate and oversized archives preserve live data', () async {
    await restored.save(
      LocalLog(
        gyms: [const Gym('old', 'Keep')],
        sessions: [],
        routes: [],
        attempts: [],
        notes: [],
        resets: [],
      ),
    );
    final old = await restored.file.readAsBytes();
    Future<void> rejects(Uint8List bad) async {
      await expectLater(LocalBackup(restored).import(bad), throwsException);
      expect(await restored.file.readAsBytes(), old);
      expect(await Directory('${target.path}/photos').exists(), isFalse);
    }

    await rejects(Uint8List.fromList([0, 1, 2]));
    await rejects(
      ZipEncoder().encodeBytes(
        Archive()..add(ArchiveFile.string('log.json', '{')),
      ),
    );
    await rejects(
      ZipEncoder().encodeBytes(
        Archive()..add(ArchiveFile.string('../log.json', '{}')),
      ),
    );
    await rejects(
      ZipEncoder().encodeBytes(
        Archive()..add(
          ArchiveFile.string(
            'log.json',
            jsonEncode((await original.load()).toJson()),
          ),
        ),
      ),
    );
    await rejects(
      ZipEncoder().encodeBytes(
        Archive()..add(
          ArchiveFile.bytes('log.json', List.filled(4 * 1024 * 1024 + 1, 1)),
        ),
      ),
    );
    // Two central-directory entries with same name: decoder's Archive deduplicates.
    final duplicate = Archive()..add(ArchiveFile.string('log.json', '{}'));
    // Archive.add itself deduplicates; emulate duplicate filename by renaming second entry after add.
    duplicate.add(ArchiveFile.string('other.json', '{}'));
    duplicate.files.last.name = 'log.json';
    await rejects(ZipEncoder().encodeBytes(duplicate));
  });

  test(
    'import removes unreferenced previous photos after successful commit',
    () async {
      final oldPhoto = 'photos/fedcba9876543210fedcba9876543210.png';
      await restored.save(
        LocalLog(
          gyms: [const Gym('old', 'Old Gym')],
          sessions: [],
          routes: [
            ClimbRoute(
              'old_r',
              'old',
              'Old',
              GradeSystem.vScale,
              'V2',
              photoPath: oldPhoto,
            ),
          ],
          attempts: [],
          notes: [],
          resets: [],
        ),
      );
      final file = File('${target.path}/$oldPhoto');
      await file.create(recursive: true);
      await file.writeAsBytes(png);
      expect(await file.exists(), isTrue);

      await LocalBackup(restored).import(zip);
      expect(await file.exists(), isFalse);
      final current = await restored.load();
      expect(current.gyms.single.name, 'Gym');
    },
  );

  test('wrong schema and corrupt payload do not replace backup', () async {
    await restored.save(
      LocalLog(
        gyms: [],
        sessions: [],
        routes: [],
        attempts: [],
        notes: [],
        resets: [],
      ),
    );
    final old = await restored.file.readAsBytes();
    final archive = Archive()
      ..add(ArchiveFile.string('log.json', '{"schema":999}'));
    await expectLater(
      LocalBackup(restored).import(ZipEncoder().encodeBytes(archive)),
      throwsFormatException,
    );
    final corrupt = Uint8List.fromList(zip);
    corrupt[40] ^= 0xff;
    await expectLater(LocalBackup(restored).import(corrupt), throwsException);
    expect(await restored.file.readAsBytes(), old);
  });
}
