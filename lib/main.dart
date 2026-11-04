import 'dart:io';

import 'package:boulder_notes/local_log.dart';
import 'package:boulder_notes/session_log.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() => runApp(const BoulderNotesApp());

typedef PhotoPicker = Future<List<int>?> Function();

class BoulderNotesApp extends StatefulWidget {
  const BoulderNotesApp({
    super.key,
    this.platform,
    this.store,
    this.pickPhoto,
    this.initialLog,
  });
  final TargetPlatform? platform;
  final LocalLogStore? store;
  final PhotoPicker? pickPhoto;
  final SessionLog? initialLog;

  @override
  State<BoulderNotesApp> createState() => _BoulderNotesAppState();
}

class _BoulderNotesAppState extends State<BoulderNotesApp> {
  SessionLog? log;
  String? gymId;
  String? sessionId;
  String? routeId;
  final gymInput = TextEditingController();
  final routeInput = TextEditingController();
  final sessionNote = TextEditingController();
  final betaNote = TextEditingController();
  bool busy = false;
  String? error;
  final grade = TextEditingController();
  final wall = TextEditingController();
  final color = TextEditingController();
  final verdict = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialLog != null) {
      log = widget.initialLog;
      gymId = log!.data.gyms.firstOrNull?.id;
      sessionId = log!.data.sessions.lastOrNull?.id;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final store =
          widget.store ??
          LocalLogStore(
            File(
              '${(await getApplicationDocumentsDirectory()).path}/boulder_log.json',
            ),
          );
      final next = SessionLog(store);
      await next.load();
      if (!mounted) return;
      setState(() {
        log = next;
        gymId = next.data.gyms.firstOrNull?.id;
        sessionId = next.data.sessions.lastOrNull?.id;
      });
    } catch (e) {
      if (mounted) setState(() => error = 'Could not load local log: $e');
    }
  }

  @override
  void dispose() {
    for (final c in [
      gymInput,
      routeInput,
      sessionNote,
      betaNote,
      grade,
      wall,
      color,
      verdict,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _save(Future<void> Function(SessionLog) change) async {
    final current = log;
    if (current == null || busy) return false;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await change(current);
      return true;
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _photo() async {
    final pick =
        widget.pickPhoto ??
        () async {
          final p = await FilePicker.pickFile(type: FileType.image);
          return p?.readAsBytes();
        };
    try {
      final selectedRoute = routeId;
      final bytes = await pick();
      if (bytes != null && selectedRoute != null) {
        await _save((l) => l.attachPhoto(selectedRoute, bytes));
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Could not select photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ios =
        (widget.platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
    final page = Builder(
      builder: (context) => SafeArea(child: _body(context, ios)),
    );
    if (ios) {
      return CupertinoApp(
        title: 'Boulder Notes',
        home: CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Boulder Notes'),
          ),
          child: page,
        ),
      );
    }
    return MaterialApp(
      title: 'Boulder Notes',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('Boulder Notes')),
        body: page,
      ),
    );
  }

  Widget _field(String label, TextEditingController c, bool ios) => ios
      ? Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: CupertinoTextField(
            key: Key('field-$label'),
            controller: c,
            placeholder: label,
            padding: const EdgeInsets.all(12),
          ),
        )
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextField(
            key: Key('field-$label'),
            controller: c,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
        );

  Widget _button(String label, VoidCallback? action, bool ios) => ios
      ? CupertinoButton(
          key: Key('action-$label'),
          onPressed: action,
          child: Text(label),
        )
      : TextButton(
          key: Key('action-$label'),
          onPressed: action,
          child: Text(label),
        );

  Widget _body(BuildContext context, bool ios) {
    final current = log;
    if (current == null) {
      return Center(child: Text(error ?? 'Loading local log…'));
    }
    final gyms = current.data.gyms;
    final sessions = current.data.sessions
        .where((s) => s.gymId == gymId)
        .toList();
    final routes = current.data.routes.where((r) => r.gymId == gymId).toList();
    final route = routes.where((r) => r.id == routeId).firstOrNull;
    final history = route == null ? <Attempt>[] : current.history(route.id);
    final controls = <Widget>[
      const Text('Your climbing log stays on this device.'),
      if (busy) const Text('Saving…'),
      if (error != null)
        Text('Could not save: $error', key: const Key('save-error')),
      _field('Gym name', gymInput, ios),
      _button('Add gym', () async {
        if (gymInput.text.trim().isEmpty) return;
        if (await _save((l) => l.addGym(gymInput.text))) {
          if (mounted) setState(() => gymId = current.data.gyms.last.id);
          gymInput.clear();
        }
      }, ios),
      if (gyms.isNotEmpty) ...[
        const Text('Gyms', style: TextStyle(fontSize: 20)),
        for (final g in gyms)
          _button(
            '${g.name}${g.id == gymId ? ' • selected' : ''}',
            () => setState(() {
              gymId = g.id;
              sessionId = current.data.sessions
                  .where((s) => s.gymId == g.id)
                  .lastOrNull
                  ?.id;
              routeId = null;
            }),
            ios,
          ),
        _field('Session note (optional)', sessionNote, ios),
        _button('New session', () async {
          if (await _save(
            (l) => l.addSession(gymId!, notes: sessionNote.text),
          )) {
            if (mounted) {
              setState(() => sessionId = current.data.sessions.last.id);
            }
            sessionNote.clear();
          }
        }, ios),
        const Text('Sessions', style: TextStyle(fontSize: 20)),
        for (final s in sessions)
          _button(
            '${s.date.substring(0, 10)} ${s.notes ?? ''}${s.id == sessionId ? ' • selected' : ''}',
            () => setState(() => sessionId = s.id),
            ios,
          ),
        _field('Route name', routeInput, ios),
        _field('Gym grade', grade, ios),
        _field('Wall section', wall, ios),
        _field('Color tag', color, ios),
        _button('Add route', () async {
          if (routeInput.text.trim().isEmpty) return;
          if (await _save(
            (l) => l.addRoute(
              gymId!,
              routeInput.text,
              grade: grade.text,
              wall: wall.text,
              color: color.text,
            ),
          )) {
            routeInput.clear();
            grade.clear();
            wall.clear();
            color.clear();
          }
        }, ios),
        const Text('Routes', style: TextStyle(fontSize: 20)),
        for (final r in routes)
          _button(
            '${r.label} ${r.grade ?? ''} ${r.wallSection ?? ''} ${r.colorTag ?? ''}${r.archivedAt == null ? '' : ' • archived'}',
            () => setState(() => routeId = r.id),
            ios,
          ),
      ],
    ];
    final detail = <Widget>[
      if (route != null) ...[
        Text(route.label, style: const TextStyle(fontSize: 22)),
        Text(
          'Grade: ${route.grade ?? 'unknown'} • Wall: ${route.wallSection ?? 'unknown'} • Color: ${route.colorTag ?? 'unknown'}',
        ),
        if (route.photoPath != null)
          Image.file(
            File('${current.store.file.parent.path}/${route.photoPath}'),
            height: 180,
            fit: BoxFit.contain,
            semanticLabel: 'Wall photo for ${route.label}',
            errorBuilder: (_, _, _) => const Text('Wall photo unavailable'),
          ),
        _button('Attach wall photo', _photo, ios),
        _field('Difficulty verdict (optional)', verdict, ios),
        if (route.archivedAt == null && sessionId != null)
          for (final result in AttemptResult.values)
            _button(
              'Log ${result == AttemptResult.send ? 'redpoint' : result.name}',
              () async {
                if (await _save(
                  (l) => l.attempt(
                    sessionId!,
                    route.id,
                    result,
                    verdict: verdict.text,
                  ),
                )) {
                  verdict.clear();
                }
              },
              ios,
            ),
        _field('Beta note', betaNote, ios),
        _button('Save beta note', () async {
          if (betaNote.text.trim().isEmpty) return;
          if (await _save((l) => l.addNote(route.id, betaNote.text))) {
            betaNote.clear();
          }
        }, ios),
        for (final n in current.data.notes.where((n) => n.routeId == route.id))
          Text(n.text),
        Text(
          'Route history • ${history.length} attempts',
          key: const Key('history-count'),
        ),
        for (final a in history)
          Text(
            '${a.at.substring(0, 10)} • ${a.result.name}${a.verdict == null ? '' : ' • ${a.verdict}'}',
          ),
        if (route.archivedAt == null)
          _button(
            'Archive route',
            () => _save((l) => l.archive(route.id)),
            ios,
          ),
      ],
    ];
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 800) {
      return Row(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: controls,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: detail,
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [...controls, ...detail],
    );
  }
}
