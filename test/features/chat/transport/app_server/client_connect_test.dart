import 'client_test_support.dart';

void main() {
  test('connect supports a transport opener without process streams', () async {
    late FakeCodexAppServerTransport transport;
    transport = FakeCodexAppServerTransport(
      onClientLine: (line) {
        final message = jsonDecode(line) as Map<String, dynamic>;
        if (message['method'] == 'initialize') {
          transport.sendProtocolMessage(<String, Object?>{
            'id': message['id'],
            'result': <String, Object?>{'userAgent': 'codex-app-server-test'},
          });
        }
      },
    );

    final client = CodexAppServerClient(
      transportOpener:
          ({required profile, required secrets, required emitEvent}) async =>
              transport,
    );
    final events = <CodexAppServerEvent>[];
    final subscription = client.events.listen(events.add);

    await client.connect(
      profile: clientProfile(),
      secrets: const ConnectionSecrets(password: 'secret'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(transport.writtenLines, hasLength(2));
    expect(
      jsonDecode(transport.writtenLines[1]) as Map<String, dynamic>,
      <String, Object?>{'method': 'initialized'},
    );

    final connected = events.whereType<CodexAppServerConnectedEvent>().single;
    expect(connected.userAgent, 'codex-app-server-test');

    await subscription.cancel();
    await client.disconnect();
  });

  test(
    'connect performs initialize handshake and emits connected event',
    () async {
      late FakeCodexAppServerProcess process;
      process = FakeCodexAppServerProcess(
        onClientMessage: (message) {
          if (message['method'] == 'initialize') {
            process.sendStdout(<String, Object?>{
              'id': message['id'],
              'result': <String, Object?>{'userAgent': 'codex-app-server-test'},
            });
          }
        },
      );

      final client = CodexAppServerClient(
        processLauncher:
            ({required profile, required secrets, required emitEvent}) async =>
                process,
      );
      final events = <CodexAppServerEvent>[];
      final subscription = client.events.listen(events.add);

      await client.connect(
        profile: clientProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(process.writtenMessages, hasLength(2));
      expect(process.writtenMessages[0]['method'], 'initialize');
      expect(process.writtenMessages[1], <String, Object?>{
        'method': 'initialized',
      });

      final connected = events.whereType<CodexAppServerConnectedEvent>().single;
      expect(connected.userAgent, 'codex-app-server-test');

      await subscription.cancel();
      await client.disconnect();
    },
  );

  test(
    'connect preserves the final stderr line when startup exits immediately',
    () async {
      late FakeCodexAppServerProcess process;
      process = FakeCodexAppServerProcess(
        exitCodeValue: 127,
        onClientMessage: (message) {
          if (message['method'] == 'initialize') {
            process.sendStderr(
              'Codex CLI not found on PATH',
              includeTrailingNewline: false,
            );
            unawaited(process.close());
          }
        },
      );

      final client = CodexAppServerClient(
        processLauncher:
            ({required profile, required secrets, required emitEvent}) async =>
                process,
      );
      final events = <CodexAppServerEvent>[];
      final subscription = client.events.listen(events.add);

      await expectLater(
        client.connect(
          profile: clientProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
        throwsA(
          isA<CodexAppServerException>().having(
            (error) => error.message,
            'message',
            contains('disconnected'),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        events.whereType<CodexAppServerDiagnosticEvent>().map((e) => e.message),
        contains('Codex CLI not found on PATH'),
      );

      await subscription.cancel();
      await client.disconnect();
    },
  );

  test('dispose closes the event stream and rejects reuse', () async {
    final client = CodexAppServerClient(
      processLauncher:
          ({required profile, required secrets, required emitEvent}) async =>
              FakeCodexAppServerProcess(),
    );
    var didCloseEvents = false;
    final subscription = client.events.listen(
      (_) {},
      onDone: () {
        didCloseEvents = true;
      },
    );

    await client.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(didCloseEvents, isTrue);
    await expectLater(
      client.connect(
        profile: clientProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      ),
      throwsA(
        isA<CodexAppServerException>().having(
          (error) => error.message,
          'message',
          contains('disposed'),
        ),
      ),
    );

    await subscription.cancel();
  });
}
