# Pull-request Platform Build Verification

Pocket Relay now keeps pull-request build verification separate from the
existing `Repo Guardrails` workflow.

This verification layer is intended to answer one narrow question from PR
evidence: does the app still build on each supported platform surface that the
repo owns today?

## Verification levels

| Platform | Runner | Verification level | Command |
| --- | --- | --- | --- |
| Android | `ubuntu-latest` | Debug APK for the production `app` flavor | `flutter build apk --debug --flavor app` |
| iOS | `macos-latest` | Debug simulator build that proves the Flutter/Xcode iOS path without device signing | `flutter build ios --debug --simulator` |
| Linux | `ubuntu-latest` | Debug desktop bundle with the repo's Linux CMake/GTK path | `flutter build linux --debug` |
| macOS | `macos-latest` | Debug desktop app build | `flutter build macos --debug` |

## Scope boundary

- This workflow verifies buildability, not release signing or store packaging.
- The iOS simulator check is intentionally not a device-signed build.
- Platform-specific root-cause issues remain tracked separately.
- In particular, issue `#118` remains the owner-layer tracker for the iOS
  native-assets and device-build path problem.

## Branch-protection intent

The PR checks exposed by `.github/workflows/pr-platform-builds.yml` are the
checks that branch protection should require when the repo wants explicit
platform build evidence for pull requests.
