import 'dart:convert';
import 'dart:io';

// ponytail: Schema 2 migrates schema 1 only; add explicit migrations when format changes.
const logSchema = 2;

enum GradeSystem { vScale, font, gymColor }

enum AttemptResult { flash, send, fail, repeat }

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key');
  }
  return value;
}

String? _optional(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  return _string(json, key);
}

String _date(Map<String, dynamic> json, String key) {
  final value = _string(json, key);
  if (DateTime.tryParse(value) == null) {
    throw FormatException('Invalid $key');
  }
  return value;
}

T _choice<T extends Enum>(
  Map<String, dynamic> json,
  String key,
  List<T> values,
) {
  final name = _string(json, key);
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  throw FormatException('Invalid $key: $name');
}

class Gym {
  const Gym(this.id, this.name);
  final String id;
  final String name;
  factory Gym.fromJson(Map<String, dynamic> j) =>
      Gym(_string(j, 'id'), _string(j, 'name'));
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class ClimbingSession {
  const ClimbingSession(this.id, this.gymId, this.date);
  final String id;
  final String gymId;
  final String date;
  factory ClimbingSession.fromJson(Map<String, dynamic> j) =>
      ClimbingSession(_string(j, 'id'), _string(j, 'gymId'), _date(j, 'date'));
  Map<String, dynamic> toJson() => {'id': id, 'gymId': gymId, 'date': date};
}

class GymReset {
  const GymReset(this.id, this.gymId, this.at);
  final String id;
  final String gymId;
  final String at;
  factory GymReset.fromJson(Map<String, dynamic> j) =>
      GymReset(_string(j, 'id'), _string(j, 'gymId'), _date(j, 'at'));
  Map<String, dynamic> toJson() => {'id': id, 'gymId': gymId, 'at': at};
}

class ClimbRoute {
  const ClimbRoute(
    this.id,
    this.gymId,
    this.label,
    this.gradeSystem,
    this.grade, {
    this.archivedAt,
    this.resetId,
  });
  final String id;
  final String gymId;
  final String label;
  final GradeSystem gradeSystem;
  final String? grade;
  final String? archivedAt;
  final String? resetId;
  factory ClimbRoute.fromJson(Map<String, dynamic> j) => ClimbRoute(
    _string(j, 'id'),
    _string(j, 'gymId'),
    _string(j, 'label'),
    _choice(j, 'gradeSystem', GradeSystem.values),
    _optional(j, 'grade'),
    archivedAt: j['archivedAt'] == null ? null : _date(j, 'archivedAt'),
    resetId: _optional(j, 'resetId'),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'gymId': gymId,
    'label': label,
    'gradeSystem': gradeSystem.name,
    'grade': grade,
    'archivedAt': archivedAt,
    'resetId': resetId,
  };
}

class Attempt {
  const Attempt(this.id, this.sessionId, this.routeId, this.result, this.at);
  final String id;
  final String sessionId;
  final String routeId;
  final AttemptResult result;
  final String at;
  factory Attempt.fromJson(Map<String, dynamic> j) => Attempt(
    _string(j, 'id'),
    _string(j, 'sessionId'),
    _string(j, 'routeId'),
    _choice(j, 'result', AttemptResult.values),
    _date(j, 'at'),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'routeId': routeId,
    'result': result.name,
    'at': at,
  };
}

class BetaNote {
  const BetaNote(this.id, this.routeId, this.text);
  final String id;
  final String routeId;
  final String text;
  factory BetaNote.fromJson(Map<String, dynamic> j) =>
      BetaNote(_string(j, 'id'), _string(j, 'routeId'), _string(j, 'text'));
  Map<String, dynamic> toJson() => {'id': id, 'routeId': routeId, 'text': text};
}

class LocalLog {
  LocalLog({
    required List<Gym> gyms,
    required List<ClimbingSession> sessions,
    required List<ClimbRoute> routes,
    required List<Attempt> attempts,
    required List<BetaNote> notes,
    required List<GymReset> resets,
  }) : gyms = List.unmodifiable(gyms),
       sessions = List.unmodifiable(sessions),
       routes = List.unmodifiable(routes),
       attempts = List.unmodifiable(attempts),
       notes = List.unmodifiable(notes),
       resets = List.unmodifiable(resets) {
    validate();
  }

  final List<Gym> gyms;
  final List<ClimbingSession> sessions;
  final List<ClimbRoute> routes;
  final List<Attempt> attempts;
  final List<BetaNote> notes;
  final List<GymReset> resets;

  LocalLog resetGym(GymReset reset) {
    if (!gyms.any((gym) => gym.id == reset.gymId) ||
        resets.any((event) => event.id == reset.id) ||
        DateTime.tryParse(reset.at) == null) {
      throw const FormatException('Invalid gym reset');
    }
    return LocalLog(
      gyms: gyms,
      sessions: sessions,
      routes: [
        for (final route in routes)
          if (route.gymId == reset.gymId && route.archivedAt == null)
            ClimbRoute(
              route.id,
              route.gymId,
              route.label,
              route.gradeSystem,
              route.grade,
              archivedAt: reset.at,
              resetId: reset.id,
            )
          else
            route,
      ],
      attempts: attempts,
      notes: notes,
      resets: [...resets, reset],
    );
  }

  void validate() {
    final ids = <String>{};
    void unique(String id) {
      if (id.trim().isEmpty || !ids.add(id)) {
        throw FormatException('Duplicate or empty ID: $id');
      }
    }

    for (final gym in gyms) {
      unique(gym.id);
      if (gym.name.trim().isEmpty) {
        throw const FormatException('Empty gym name');
      }
    }
    for (final session in sessions) {
      unique(session.id);
      _requireDate(session.date);
    }
    for (final route in routes) {
      unique(route.id);
      if (route.label.trim().isEmpty ||
          (route.grade != null && route.grade!.trim().isEmpty)) {
        throw const FormatException('Invalid route');
      }
      if (route.archivedAt != null) {
        _requireDate(route.archivedAt!);
      }
    }
    for (final reset in resets) {
      unique(reset.id);
      _requireDate(reset.at);
    }
    for (final attempt in attempts) {
      unique(attempt.id);
      _requireDate(attempt.at);
    }
    for (final note in notes) {
      unique(note.id);
      if (note.text.trim().isEmpty) {
        throw const FormatException('Empty note');
      }
    }
    final gymById = {for (final gym in gyms) gym.id: gym};
    final sessionById = {for (final session in sessions) session.id: session};
    final routeById = {for (final route in routes) route.id: route};
    final resetById = {for (final reset in resets) reset.id: reset};
    for (final session in sessions) {
      if (!gymById.containsKey(session.gymId)) {
        throw const FormatException('Orphan session');
      }
    }
    for (final reset in resets) {
      if (!gymById.containsKey(reset.gymId)) {
        throw const FormatException('Orphan reset');
      }
    }
    for (final route in routes) {
      if (!gymById.containsKey(route.gymId)) {
        throw const FormatException('Orphan route');
      }
      if (route.resetId != null &&
          (route.archivedAt == null ||
              resetById[route.resetId]?.gymId != route.gymId ||
              route.archivedAt != resetById[route.resetId]?.at)) {
        throw const FormatException('Invalid route reset');
      }
    }
    for (final attempt in attempts) {
      if (sessionById[attempt.sessionId] == null ||
          routeById[attempt.routeId] == null ||
          sessionById[attempt.sessionId]!.gymId !=
              routeById[attempt.routeId]!.gymId) {
        throw const FormatException('Cross-gym or orphan attempt');
      }
    }
    for (final note in notes) {
      if (!routeById.containsKey(note.routeId)) {
        throw const FormatException('Orphan note');
      }
    }
  }

  static void _requireDate(String date) {
    if (DateTime.tryParse(date) == null) {
      throw const FormatException('Invalid date');
    }
  }

  Map<String, dynamic> toJson() => {
    'schema': logSchema,
    'gyms': gyms.map((e) => e.toJson()).toList(),
    'sessions': sessions.map((e) => e.toJson()).toList(),
    'routes': routes.map((e) => e.toJson()).toList(),
    'attempts': attempts.map((e) => e.toJson()).toList(),
    'notes': notes.map((e) => e.toJson()).toList(),
    'resets': resets.map((e) => e.toJson()).toList(),
  };

  factory LocalLog.fromJson(Map<String, dynamic> json) {
    final schema = json['schema'];
    if (schema != 1 && schema != logSchema) {
      throw FormatException('Unsupported schema: $schema');
    }
    List<T> read<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = json[key];
      if (raw is! List) {
        throw FormatException('Missing $key');
      }
      try {
        return raw
            .map((e) => parse(Map<String, dynamic>.from(e as Map)))
            .toList();
      } on TypeError {
        throw FormatException('Invalid $key');
      }
    }

    // Version 1 has neither reset events nor archive fields.
    if (schema == 1 &&
        (json.containsKey('resets') ||
            (json['routes'] is List &&
                (json['routes'] as List).any(
                  (e) =>
                      e is Map &&
                      (e.containsKey('archivedAt') || e.containsKey('resetId')),
                )))) {
      throw const FormatException('Invalid schema 1 fields');
    }
    return LocalLog(
      gyms: read('gyms', Gym.fromJson),
      sessions: read('sessions', ClimbingSession.fromJson),
      routes: read('routes', ClimbRoute.fromJson),
      attempts: read('attempts', Attempt.fromJson),
      notes: read('notes', BetaNote.fromJson),
      resets: schema == 1 ? [] : read('resets', GymReset.fromJson),
    );
  }
}

class LocalLogStore {
  const LocalLogStore(this.file);
  final File file;

  Future<LocalLog> load() async {
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Invalid root');
      }
      return LocalLog.fromJson(json);
    } on FileSystemException {
      if (!await file.exists()) {
        throw StateError('No local log at ${file.path}');
      }
      rethrow;
    }
  }

  Future<void> save(LocalLog log) async {
    log.validate();
    final data = utf8.encode(jsonEncode(log.toJson()));
    await file.parent.create(recursive: true);
    final temp = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.$pid.tmp',
    );
    try {
      await temp.writeAsBytes(data, flush: true);
      await temp.rename(file.path);
      // ponytail: File rename is atomic for same-volume replacement; directory fsync/power-loss durability needs native platform support.
    } finally {
      if (await temp.exists()) {
        await temp.delete();
      }
    }
  }
}
