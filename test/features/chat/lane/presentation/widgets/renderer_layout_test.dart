import 'renderer_test_support.dart';

void main() {
  testWidgets('renders the explicit shell regions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: FlutterChatScreenRenderer(
          platformBehavior: PocketPlatformBehavior.resolve(),
          screen: screenContract(),
          appChrome: const TestAppChrome(),
          transcriptRegion: const Center(child: Text('Transcript region')),
          composerRegion: const Text('Composer region'),
          onStopActiveTurn: () async {},
        ),
      ),
    );

    expect(find.text('Injected chrome'), findsOneWidget);
    expect(find.text('Transcript region'), findsOneWidget);
    expect(find.text('Composer region'), findsOneWidget);
  });

  testWidgets(
    'renders an injected supplemental status region above transcript',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPocketTheme(Brightness.light),
          home: FlutterChatScreenRenderer(
            platformBehavior: PocketPlatformBehavior.resolve(),
            screen: screenContract(),
            appChrome: const TestAppChrome(),
            transcriptRegion: const Center(child: Text('Transcript region')),
            composerRegion: const Text('Composer region'),
            supplementalStatusRegion: const Text('Connection strip'),
            onStopActiveTurn: () async {},
          ),
        ),
      );

      expect(find.text('Connection strip'), findsOneWidget);
      expect(find.text('Transcript region'), findsOneWidget);
    },
  );

  testWidgets(
    'desktop renderer centers transcript and composer inside a shared lane width',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildPocketTheme(Brightness.light),
          home: FlutterChatScreenRenderer(
            platformBehavior: PocketPlatformBehavior.resolve(
              platform: TargetPlatform.macOS,
            ),
            screen: screenContract(),
            appChrome: const TestAppChrome(),
            transcriptRegion: const SizedBox.expand(
              child: ColoredBox(color: Colors.red),
            ),
            composerRegion: const SizedBox(
              height: 72,
              child: ColoredBox(color: Colors.blue),
            ),
            onStopActiveTurn: () async {},
          ),
        ),
      );
      await tester.pump();

      final transcriptRect = tester.getRect(
        find.byKey(const ValueKey('desktop_chat_transcript_region')),
      );
      final composerRect = tester.getRect(
        find.byKey(const ValueKey('desktop_chat_composer_region')),
      );

      expect(transcriptRect.width, moreOrLessEquals(1120, epsilon: 0.01));
      expect(composerRect.width, moreOrLessEquals(1120, epsilon: 0.01));
      expect(composerRect.left, moreOrLessEquals(transcriptRect.left));
      expect(
        1600 - transcriptRect.right,
        moreOrLessEquals(transcriptRect.left),
      );
    },
  );
}
