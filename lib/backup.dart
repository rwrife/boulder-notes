import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:boulder_notes/local_log.dart';

// ponytail: Whole-archive buffering is capped at 64 MiB; switch to a bounded
// streaming ZIP reader/writer if multi-gigabyte photo libraries become needed.
const maxBackupBytes = 64 * 1024 * 1024;
const _maxPhotoBytes = 15 * 1024 * 1024;
const _maxJsonBytes = 4 * 1024 * 1024;
const _maxEntries = 129;
final _photoName = RegExp(r'^photos/[a-f0-9]{32}\.(jpg|png|webp)$');
final _random = Random.secure();

String _newName(String extension) =>
    'photos/${List<int>.generate(16, (_) => _random.nextInt(256)).map((n) => n.toRadixString(16).padLeft(2, '0')).join()}.$extension';

/// Portable ZIP: log.json plus referenced photos only. Import replaces the log.
class LocalBackup {
  const LocalBackup(this.store);
  final LocalLogStore store;

  Future<Uint8List> export() async {
    final log = await store.load();
    final json = utf8.encode(jsonEncode(log.toJson()));
    if (json.length > _maxJsonBytes) {
      throw const FormatException('Log too large');
    }
    if (await FileSystemEntity.type(
          store.file.parent.path,
          followLinks: false,
        ) ==
        FileSystemEntityType.link) {
      throw const FormatException('Linked storage directory');
    }
    final paths = log.routes
        .map((r) => r.photoPath)
        .whereType<String>()
        .toSet();
    if (paths.length + 1 > _maxEntries) {
      throw const FormatException('Too many photos');
    }
    final archive = Archive()..add(ArchiveFile.bytes('log.json', json));
    var total = json.length;
    final photos = store.file.parent;
    for (final path in paths) {
      if (!_photoName.hasMatch(path)) {
        throw const FormatException('Invalid photo path');
      }
      if (await FileSystemEntity.type(
            '${photos.path}${Platform.pathSeparator}photos',
            followLinks: false,
          ) ==
          FileSystemEntityType.link) {
        throw const FormatException('Linked photo directory');
      }
      final file = File('${photos.path}${Platform.pathSeparator}$path');
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw FormatException('Missing or linked photo: $path');
      }
      final length = await file.length();
      if (length < 1 ||
          length > _maxPhotoBytes ||
          total + length > maxBackupBytes) {
        throw const FormatException('Photo or backup too large');
      }
      final bytes = await file.readAsBytes();
      total += bytes.length;
      archive.add(ArchiveFile.bytes(path, bytes));
    }
    final result = ZipEncoder().encodeBytes(archive);
    if (result.length > maxBackupBytes) {
      throw const FormatException('Backup too large');
    }
    return result;
  }

  Future<void> import(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxBackupBytes) {
      throw const FormatException('Backup too large or empty');
    }
    final seen = <String>{};
    var total = 0;
    // Decoder deduplicates names; callback catches duplicates before replacement.
    final archive = ZipDecoder().decodeBytes(
      bytes,
      verify: true,
      callback: (entry) {
        if (!entry.isFile ||
            entry.isSymbolicLink ||
            !seen.add(entry.name) ||
            (entry.name != 'log.json' && !_photoName.hasMatch(entry.name)) ||
            entry.size < 0 ||
            entry.size >
                (entry.name == 'log.json' ? _maxJsonBytes : _maxPhotoBytes)) {
          throw const FormatException('Invalid backup entry');
        }
        total += entry.size;
        if (seen.length > _maxEntries || total > maxBackupBytes) {
          throw const FormatException('Backup expanded too large');
        }
      },
    );
    final jsonEntry = archive.find('log.json');
    if (jsonEntry == null) throw const FormatException('Missing log.json');
    final decoded = jsonDecode(utf8.decode(jsonEntry.readBytes()!));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup log');
    }
    final log = LocalLog.fromJson(decoded);
    final paths = log.routes
        .map((r) => r.photoPath)
        .whereType<String>()
        .toSet();
    if (seen.length != paths.length + 1 ||
        paths.any(
          (path) => !_photoName.hasMatch(path) || !seen.contains(path),
        )) {
      throw const FormatException('Missing or unreferenced photo');
    }
    // Validate every byte and CRC before touching live storage.
    final contents = <String, Uint8List>{};
    for (final path in paths) {
      final content = archive.find(path)!.readBytes()!;
      if (content.isEmpty || content.length > _maxPhotoBytes) {
        throw const FormatException('Invalid photo');
      }
      contents[path] = content;
    }
    final replacement = <String, String>{
      for (final path in paths) path: _newName(path.split('.').last),
    };
    final restored = LocalLog.fromJson({
      ...log.toJson(),
      'routes': [
        for (final route in log.routes)
          {...route.toJson(), 'photoPath': replacement[route.photoPath]},
      ],
    });
    final created = <File>[];
    try {
      final photoDir = Directory(
        '${store.file.parent.path}${Platform.pathSeparator}photos',
      );
      final type = await FileSystemEntity.type(
        photoDir.path,
        followLinks: false,
      );
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.directory) {
        throw const FormatException('Unsafe photo directory');
      }
      if (contents.isNotEmpty) await photoDir.create(recursive: true);
      for (final entry in contents.entries) {
        final file = File(
          '${store.file.parent.path}${Platform.pathSeparator}${replacement[entry.key]}',
        );
        // Unique names never replace existing photos, even on ID collision.
        if (await file.exists()) {
          throw const FormatException('Photo ID collision');
        }
        created.add(file);
        await file.writeAsBytes(entry.value, flush: true);
      }
      final previous = await store.file.exists() ? await store.load() : null;
      await store.save(restored);
      // New log is committed; old photos are no longer referenced. Cleanup is
      // best-effort, never report import failure after the replacement succeeded.
      for (final oldPath
          in previous?.routes
                  .map((r) => r.photoPath)
                  .whereType<String>()
                  .toSet() ??
              <String>{}) {
        if (!_photoName.hasMatch(oldPath) ||
            await FileSystemEntity.type(photoDir.path, followLinks: false) !=
                FileSystemEntityType.directory) {
          continue;
        }
        try {
          final oldFile = File(
            '${store.file.parent.path}${Platform.pathSeparator}$oldPath',
          );
          if (await FileSystemEntity.type(oldFile.path, followLinks: false) ==
              FileSystemEntityType.file) {
            await oldFile.delete();
          }
        } on FileSystemException {
          // ponytail: Orphan photos after failed cleanup are removed by data wipe.
        }
      }
    } catch (_) {
      for (final file in created) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
  }

  Future<void> deleteAll() async {
    // Remove log first. If deletion fails, photos remain recoverable; a later
    // cleanup error leaves only unreferenced photos, never a broken live log.
    if (await store.file.exists()) await store.file.delete();
    final photos = Directory(
      '${store.file.parent.path}${Platform.pathSeparator}photos',
    );
    if (await photos.exists()) await photos.delete(recursive: true);
  }
}
