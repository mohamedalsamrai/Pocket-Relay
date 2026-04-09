import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/platform/app_lifecycle_visibility.dart';

void main() {
  test('projects Flutter app lifecycle states into visibility states', () {
    expect(
      appLifecycleVisibilityForState(null),
      AppLifecycleVisibility.foreground,
    );
    expect(
      appLifecycleVisibilityForState(AppLifecycleState.resumed),
      AppLifecycleVisibility.foreground,
    );
    expect(
      appLifecycleVisibilityForState(AppLifecycleState.inactive),
      AppLifecycleVisibility.background,
    );
    expect(
      appLifecycleVisibilityForState(AppLifecycleState.hidden),
      AppLifecycleVisibility.background,
    );
    expect(
      appLifecycleVisibilityForState(AppLifecycleState.paused),
      AppLifecycleVisibility.background,
    );
    expect(
      appLifecycleVisibilityForState(AppLifecycleState.detached),
      AppLifecycleVisibility.detached,
    );
  });

  test('foreground visibility helpers match continuity host behavior', () {
    expect(appLifecycleStateIsForegroundVisible(null), isTrue);
    expect(
      appLifecycleStateIsForegroundVisible(AppLifecycleState.resumed),
      isTrue,
    );
    expect(
      appLifecycleStateIsForegroundVisible(AppLifecycleState.inactive),
      isFalse,
    );
    expect(
      appLifecycleStateIsForegroundVisible(AppLifecycleState.hidden),
      isFalse,
    );
    expect(
      appLifecycleStateIsForegroundVisible(AppLifecycleState.paused),
      isFalse,
    );
    expect(
      appLifecycleStateIsForegroundVisible(AppLifecycleState.detached),
      isFalse,
    );

    expect(appLifecycleStateIsNotForegroundVisible(null), isFalse);
    expect(
      appLifecycleStateIsNotForegroundVisible(AppLifecycleState.resumed),
      isFalse,
    );
    expect(
      appLifecycleStateIsNotForegroundVisible(AppLifecycleState.inactive),
      isTrue,
    );
    expect(
      appLifecycleStateIsNotForegroundVisible(AppLifecycleState.hidden),
      isTrue,
    );
    expect(
      appLifecycleStateIsNotForegroundVisible(AppLifecycleState.paused),
      isTrue,
    );
    expect(
      appLifecycleStateIsNotForegroundVisible(AppLifecycleState.detached),
      isTrue,
    );
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
