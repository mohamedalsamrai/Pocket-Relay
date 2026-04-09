import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/platform/app_lifecycle_visibility.dart';

void main() {
  test('projects Flutter app lifecycle states into visibility states', () {
    final cases = <({AppLifecycleState? state, AppLifecycleVisibility result})>[
      (state: null, result: AppLifecycleVisibility.foreground),
      (
        state: AppLifecycleState.resumed,
        result: AppLifecycleVisibility.foreground,
      ),
      (
        state: AppLifecycleState.inactive,
        result: AppLifecycleVisibility.background,
      ),
      (
        state: AppLifecycleState.hidden,
        result: AppLifecycleVisibility.background,
      ),
      (
        state: AppLifecycleState.paused,
        result: AppLifecycleVisibility.background,
      ),
      (
        state: AppLifecycleState.detached,
        result: AppLifecycleVisibility.detached,
      ),
    ];

    for (final testCase in cases) {
      expect(
        appLifecycleVisibilityForState(testCase.state),
        testCase.result,
        reason: '${testCase.state} should project to ${testCase.result}',
      );
    }
  });

  test('foreground visibility helpers match continuity host behavior', () {
    final cases = <({AppLifecycleState? state, bool isForeground})>[
      (state: null, isForeground: true),
      (state: AppLifecycleState.resumed, isForeground: true),
      (state: AppLifecycleState.inactive, isForeground: false),
      (state: AppLifecycleState.hidden, isForeground: false),
      (state: AppLifecycleState.paused, isForeground: false),
      (state: AppLifecycleState.detached, isForeground: false),
    ];

    for (final testCase in cases) {
      expect(
        appLifecycleStateIsForegroundVisible(testCase.state),
        testCase.isForeground,
        reason: '${testCase.state} should match foreground visibility',
      );
      expect(
        appLifecycleStateIsNotForegroundVisible(testCase.state),
        !testCase.isForeground,
        reason: '${testCase.state} should match non-foreground visibility',
      );
    }
  });
}
