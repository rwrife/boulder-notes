# Boulder Notes plan

## Scope and architecture

Flutter stable (Dart) single codebase; scaffold `windows/`, `android/`, `ios/` in issue #1. `com.infinityball.bouldernotes` across Android applicationId, iOS bundle ID and Windows/MSIX identity where applicable. Local-only versioned JSON repository with stable UUIDs and atomic writes; photo attachments in app-private storage. Export zip with JSON + photos; validate schema, relative paths, size bounds and duplicates before import; never overwrite an existing backup on failure. No new persistence dependency until stdlib/file storage proves inadequate.

## Platform-authentic UX: A

Small adaptive widget seam (`BoulderWorkspaceLayout`, shared domain, platform renderers). Cupertino on iOS/iPadOS, Material 3 on Android, Fluent-style desktop navigation/command surface on Windows (`fluent_ui` only if built-in widgets cannot meet behavior). Never ship Material on iOS, Cupertino on Android, or phone layout on Windows. Native file/photo pickers; system back/gesture, scroll physics, safe areas and font scaling. Width-aware detail pane on tablet/desktop; compact stack on phone. Touch + keyboard/mouse/hover, focus order and shortcuts. Golden/widget tests at TargetPlatform.iOS, TargetPlatform.android and TargetPlatform.windows, plus phone/tablet/desktop sizes.

## Milestones

1. Flutter platform folders, exact identifier, pinned toolchain docs and Windows/Android CI.
2. Pure Dart local data contract and deterministic persistence tests.
3. Session/route/attempt workflow with route reset history.
4. Adaptive accessible UI and cross-platform screenshots/tests.
5. Backup/import/privacy validation and recovery tests.
6. Real `AppStore/icon.png` via `spark-media image` using documented brief, wire Windows/Android/iOS icon sets; review `AppStore/description.txt` against implementation.
7. `.github/workflows/release.yml`: `v*` tag/manual dispatch, `windows-latest` release build, zip and GitHub release asset. Later opt-in TestFlight/Play via ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, ASC_TEAM_ID; never publish without consent. App Store Connect bundle ID blocked by `FORBIDDEN_ERROR.PLA_NOT_ACCEPTED` pending account-owner agreement.

## Verification and release

Use a pinned Flutter stable toolchain documented in `docs/toolchain.json` once issue #1 selects an observed version. `flutter test` + `flutter build windows --release` on windows-latest; `flutter build apk --debug` in Linux CI. Local Linux checks run inside Docker. iOS compile on macOS CI when available, before any store submission. Report actual lanes, not inferred support. Zip Windows portable build on `v*`, inspect asset. No released app exists today.

## Risks and non-goals

Gyms reset route colors and grade systems; preserve gym-local grade strings and archived route versions, never compare unlike grades without explicit mapping. User photos may be large or contain bystanders: user-selected only, no automatic uploads; bound import size and strip nothing without consent. No image recognition, coaching/medical claims, leaderboard, hosted account or sync. This is personal logging, not medical advice.
