import 'dart:io';
import 'dart:math';

import 'package:boulder_notes/local_log.dart';

final _random = Random.secure();
String _id() => List<int>.generate(
  16,
  (_) => _random.nextInt(256),
).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

// Image type must come from file content, not caller-controlled file name.
String _imageExtension(List<int> b) {
  if (b.length >= 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) {
    return 'jpg';
  }
  if (b.length >= 8 &&
      b[0] == 137 &&
      b[1] == 80 &&
      b[2] == 78 &&
      b[3] == 71 &&
      b[4] == 13 &&
      b[5] == 10 &&
      b[6] == 26 &&
      b[7] == 10) {
    return 'png';
  }
  if (b.length >= 12 &&
      String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
    return 'webp';
  }
  throw const FormatException('Unsupported photo format');
}

/// One persisted local session journal. No service, sync, or implicit network.
class SessionLog {
  SessionLog(this.store);
  final LocalLogStore store;
  LocalLog data = LocalLog(
    gyms: [],
    sessions: [],
    routes: [],
    attempts: [],
    notes: [],
    resets: [],
  );

  Future<void> load() async {
    if (await store.file.exists()) data = await store.load();
  }

  Future<void> _commit(LocalLog next) async {
    await store.save(next);
    data = next;
  }

  // ponytail: Random.secure IDs avoid collisions; add UUID formatting only if external tools require it.

  LocalLog _copy({
    List<Gym>? gyms,
    List<ClimbingSession>? sessions,
    List<ClimbRoute>? routes,
    List<Attempt>? attempts,
    List<BetaNote>? notes,
  }) => LocalLog(
    gyms: gyms ?? data.gyms,
    sessions: sessions ?? data.sessions,
    routes: routes ?? data.routes,
    attempts: attempts ?? data.attempts,
    notes: notes ?? data.notes,
    resets: data.resets,
  );

  Future<void> addGym(String name) {
    if (name.trim().isEmpty) throw const FormatException('Empty gym name');
    return _commit(_copy(gyms: [...data.gyms, Gym(_id(), name.trim())]));
  }

  Future<void> addSession(String gymId, {String? notes, DateTime? date}) =>
      _commit(
        _copy(
          sessions: [
            ...data.sessions,
            ClimbingSession(
              _id(),
              gymId,
              (date ?? DateTime.now()).toIso8601String(),
              notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
            ),
          ],
        ),
      );
  Future<void> addRoute(
    String gymId,
    String label, {
    String? grade,
    String? wall,
    String? color,
    String? photoPath,
  }) {
    if (label.trim().isEmpty) throw const FormatException('Empty route name');
    return _commit(
      _copy(
        routes: [
          ...data.routes,
          ClimbRoute(
            _id(),
            gymId,
            label.trim(),
            GradeSystem.vScale,
            grade?.trim().isEmpty == true ? null : grade?.trim(),
            wallSection: wall?.trim().isEmpty == true ? null : wall?.trim(),
            colorTag: color?.trim().isEmpty == true ? null : color?.trim(),
            photoPath: photoPath,
          ),
        ],
      ),
    );
  }

  Future<void> attempt(
    String sessionId,
    String routeId,
    AttemptResult result, {
    String? verdict,
  }) {
    final route = data.routes.singleWhere((e) => e.id == routeId);
    if (route.archivedAt != null) throw StateError('Route archived');
    final session = data.sessions.singleWhere((e) => e.id == sessionId);
    if (session.gymId != route.gymId) {
      throw const FormatException('Cross-gym attempt');
    }
    return _commit(
      _copy(
        attempts: [
          ...data.attempts,
          Attempt(
            _id(),
            sessionId,
            routeId,
            result,
            DateTime.now().toIso8601String(),
            verdict: verdict?.trim().isEmpty == true ? null : verdict?.trim(),
          ),
        ],
      ),
    );
  }

  Future<void> addNote(String routeId, String text) {
    if (text.trim().isEmpty) throw const FormatException('Empty note');
    return _commit(
      _copy(notes: [...data.notes, BetaNote(_id(), routeId, text.trim())]),
    );
  }

  Future<void> archive(String routeId) async {
    final at = DateTime.now().toIso8601String();
    await _commit(
      _copy(
        routes: [
          for (final route in data.routes)
            if (route.id == routeId && route.archivedAt == null)
              ClimbRoute(
                route.id,
                route.gymId,
                route.label,
                route.gradeSystem,
                route.grade,
                archivedAt: at,
                resetId: route.resetId,
                wallSection: route.wallSection,
                colorTag: route.colorTag,
                photoPath: route.photoPath,
                difficulty: route.difficulty,
              )
            else
              route,
        ],
      ),
    );
  }

  List<Attempt> history(String routeId) =>
      data.attempts.where((e) => e.routeId == routeId).toList();

  // ponytail: Image originals remain unchanged; add thumbnail generation when galleries need it.
  Future<void> attachPhoto(String routeId, List<int> bytes) async {
    if (bytes.isEmpty || bytes.length > 15 * 1024 * 1024) {
      throw const FormatException('Photo must be 1–15 MB');
    }
    if (!data.routes.any((r) => r.id == routeId && r.archivedAt == null)) {
      throw const FormatException('Missing or archived route');
    }
    final name = '${_id()}.${_imageExtension(bytes)}';
    final photo = File('${store.file.parent.path}/photos/$name');
    await photo.parent.create(recursive: true);
    try {
      await photo.writeAsBytes(bytes, flush: true);
      await _commit(
        _copy(
          routes: [
            for (final route in data.routes)
              if (route.id == routeId)
                ClimbRoute(
                  route.id,
                  route.gymId,
                  route.label,
                  route.gradeSystem,
                  route.grade,
                  archivedAt: route.archivedAt,
                  resetId: route.resetId,
                  wallSection: route.wallSection,
                  colorTag: route.colorTag,
                  photoPath: 'photos/$name',
                  difficulty: route.difficulty,
                )
              else
                route,
          ],
        ),
      );
    } catch (_) {
      if (await photo.exists()) await photo.delete();
      rethrow;
    }
  }
}
