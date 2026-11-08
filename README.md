# Boulder Notes

Offline bouldering session log: capture route attempts, wall snapshots, personal grade notes, and progress on phone, tablet, and Windows without accounts.

## Why and for whom

Indoor boulderers often forget which holds they tried and why an attempt failed. Boulder Notes keeps private, gym-specific session history. It is a personal journal, not a grading authority or coaching service.

## Workflow

1. Create a gym and session. Add a route with its wall location, gym grade, optional wall photo, and date.
2. Record attempts, send status, optional personal difficulty and one short beta note. A route may be reset by a gym; archive the old version instead of overwriting history.
3. Review sessions and simple totals by gym, grade and time. Export JSON plus attached photos as a portable local backup; import without duplicate entries.

## MVP

- Local gyms, sessions, routes, attempts, notes and optional photos; no login or network.
- Attempt history and honest counts (ungraded/unknown excluded from grade trends).
- Adaptive phone, tablet and desktop screens with touch, keyboard, mouse and accessible labels.
- Portable backup and restore; clear local-data deletion.
- Windows zip release from a `v*` tag.

Non-goals: route recognition, grade prediction, leaderboards, shared gym databases, injury advice, medical claims, GPS tracking, subscription or cloud sync. This app is not a medical or training prescription.

## Platforms and privacy

Flutter stable, Windows/Android/iOS single codebase. iPhone, iPad and Android tablets enabled. `com.infinityball.bouldernotes` is Android applicationId and iOS bundle ID. Photos stay on device; user chooses photo access via platform picker. No background camera, location or network permission. User-initiated export writes only chosen files. Screen reader labels, scalable text, high contrast, and full keyboard navigation required. Windows uses desktop navigation/shortcuts; iOS Cupertino; Android Material 3. PLAN.md records adaptation contract.

## Status and development

Flutter 3.47.7/Dart 3.13.5 scaffold with Windows, Android and iOS runners. Pure Dart versioned local log model and atomic JSON file store support gym/session/route logging, one-tap attempts, personal verdicts, beta notes, archive history and optional local photo attachments via native picker. User-initiated ZIP backup exports `log.json` and referenced photos; import validates schema, paths, sizes, and duplicate names, then replaces local log. Import and wipe require confirmation; back up before wiping. Backup files are unencrypted: keep copies secure. Adaptive desktop navigation, platform-specific icons and Windows release packaging exist. On Linux ARM64, run pinned Flutter checks inside a container or use matching ARM64-Dart Flutter graft; Windows and Android builds require CI evidence. Run `flutter pub get --enforce-lockfile`, `flutter analyze`, `flutter test`; Windows CI runs `flutter build windows --release`, Android CI runs `flutter build apk --debug`. iOS compile awaits macOS CI. AppStore/description.txt describes current features.

## Release

`.github/workflows/release.yml` triggers on `v*` tag pushes or manual `workflow_dispatch` with an explicit existing `tag` parameter. Pull requests changing the release workflow or README run a build-and-archive dry run without publishing. The workflow builds the Windows portable application on `windows-latest` via `flutter build windows --release`, packages and verifies the portable release ZIP (`boulder_notes.exe`, `flutter_windows.dll`, Visual C++ runtime DLLs, and Flutter data assets), then publishes the archive to a GitHub Release for the tag. No release is published by a pull request.

Android Play and iOS TestFlight are later opt-in milestones. ASC secret names `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, and `ASC_TEAM_ID` are reserved for future iOS publishing; secret values never enter the repository or release workflow logs.

## Manual setup required

`com.infinityball.bouldernotes` could not be registered in App Store Connect: `FAILED bundleId lookup rejected: FORBIDDEN_ERROR.PLA_NOT_ACCEPTED`. Account owner must accept current Apple Program License Agreement, then rerun bundle-ID registration. Do not claim registration succeeded.

MIT license.
