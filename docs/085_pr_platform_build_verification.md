# Pull Request Platform Verification

Pocket Relay now keeps pull-request verification separate from the existing
`Repo Guardrails` workflow.

This verification layer is intended to answer one narrow question from PR
evidence: does the shared regression suite still pass, and does the app still
build on each supported platform surface that the repo owns today?

## Shared regression coverage

| Check | Runner | Verification level | Command |
| --- | --- | --- | --- |
| Regression tests | `ubuntu-latest` | Full Flutter regression suite for app-owned tests, split into three parallel shards behind one required check | `flutter test --no-pub --total-shards 3 --shard-index [0-2]` |

## Verification levels

| Platform | Runner | Verification level | Command |
| --- | --- | --- | --- |
| Android | `ubuntu-latest` | Debug arm64 APK for the production `app` flavor | `flutter build apk --debug --flavor app --target-platform android-arm64 --no-pub` |
| iOS | `macos-latest` | Debug simulator build that proves the Flutter/Xcode iOS path without device signing | `flutter build ios --debug --simulator --no-pub` |
| Linux | `ubuntu-latest` | Debug desktop bundle with the repo's Linux CMake/GTK path | `flutter build linux --debug --no-pub` |
| macOS | `macos-latest` | Debug desktop app build | `flutter build macos --debug --no-pub` |

## Scope boundary

- This workflow verifies shared regression coverage plus buildability.
- It does not prove end-to-end runtime behavior on every target.
- It does not prove release signing or store packaging.
- Android PR verification intentionally validates the primary arm64 build path
  instead of a full multi-ABI APK fan-out.
- The iOS simulator check is intentionally not a device-signed build.
- Platform-specific root-cause issues remain tracked separately.
- In particular, issue `#118` remains the owner-layer tracker for the iOS
  native-assets and device-build path problem.

## Branch-protection intent

The PR checks exposed by `.github/workflows/pr-platform-builds.yml` are the
checks that branch protection should require when the repo wants explicit
regression and platform-build evidence for pull requests.

The required regression gate remains `Regression tests`, even though the suite
now runs under three parallel shard jobs internally.
