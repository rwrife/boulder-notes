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

Planning scaffold only: no running application, generated icon, build results or release yet. Implement issues in order. Install Flutter stable and platform SDKs, then run `flutter create --platforms=windows,android,ios .`, `flutter test`, `flutter build windows --release`, `flutter build apk --debug`; verify Linux-hosted checks in a pinned Docker Flutter image. Platform-specific build claims require CI evidence. AppStore/description.txt describes planned behavior, not released features. Icon generation via OpenAI Images spark-media remains backlog work.

## Release

`.github/workflows/release.yml` must trigger on `v*` tags or manual dispatch, build Windows on `windows-latest`, zip output and attach a GitHub release asset. Android Play and iOS TestFlight are later opt-in milestones. ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, ASC_TEAM_ID names are configured for later iOS publishing; secret values never enter repository.

## Manual setup required

`com.infinityball.bouldernotes` could not be registered in App Store Connect: `FAILED bundleId lookup rejected: FORBIDDEN_ERROR.PLA_NOT_ACCEPTED`. Account owner must accept current Apple Program License Agreement, then rerun bundle-ID registration. Do not claim registration succeeded.

MIT license.
