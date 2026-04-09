import 'package:flutter/foundation.dart';
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

  testWidgets('visibility builder publishes projected lifecycle changes', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    ValueListenable<AppLifecycleVisibility>? visibilityListenable;

    await tester.pumpWidget(
      AppLifecycleVisibilityBuilder(
        builder: (context, listenable) {
          visibilityListenable = listenable;
          return const SizedBox();
        },
      ),
    );

    expect(visibilityListenable!.value, AppLifecycleVisibility.foreground);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    expect(visibilityListenable!.value, AppLifecycleVisibility.background);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(visibilityListenable!.value, AppLifecycleVisibility.foreground);
  });
}
