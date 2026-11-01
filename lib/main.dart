import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() => runApp(const BoulderNotesApp());

/// Bootstrap-only shell. Session logging and storage arrive in later issues.
class BoulderNotesApp extends StatelessWidget {
  const BoulderNotesApp({super.key, this.platform});

  final TargetPlatform? platform;

  @override
  Widget build(BuildContext context) {
    final target = platform ?? defaultTargetPlatform;
    if (target == TargetPlatform.iOS) {
      return const CupertinoApp(
        title: 'Boulder Notes',
        home: CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(middle: Text('Boulder Notes')),
          child: SafeArea(
            child: Center(
              child: Text('Your climbing log stays on this device.'),
            ),
          ),
        ),
      );
    }
    return MaterialApp(
      title: 'Boulder Notes',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('Boulder Notes')),
        body: const Center(
          child: Text('Your climbing log stays on this device.'),
        ),
      ),
    );
  }
}
