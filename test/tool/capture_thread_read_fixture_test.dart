import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/capture_live_thread_read_fixture/capture_options.dart';
import '../../tool/capture_live_thread_read_fixture/capture_output.dart';
import '../../tool/capture_live_thread_read_fixture.dart';

void main() {
  test(
    'buildCodexLaunchInvocation preserves shell launch commands on POSIX',
    () {
      final invocation = buildCodexLaunchInvocation(
        r'PATH="$HOME/bin:$PATH" codex',
        platform: TargetPlatform.macOS,
      );

      expect(invocation.executable, 'bash');
      expect(invocation.arguments, <String>[
        '-lc',
        r'PATH="$HOME/bin:$PATH" codex app-server --listen stdio://',
      ]);
    },
  );

  test(
    'buildCodexLaunchInvocation preserves chained shell wrappers on POSIX',
    () {
      final invocation = buildCodexLaunchInvocation(
        'source ~/.asdf/asdf.sh && codex',
        platform: TargetPlatform.linux,
      );

      expect(invocation.executable, 'bash');
      expect(invocation.arguments, <String>[
        '-lc',
        'source ~/.asdf/asdf.sh && codex app-server --listen stdio://',
      ]);
    },
  );

  test(
    'buildCodexLaunchInvocation preserves shell launch commands on Windows',
    () {
      final invocation = buildCodexLaunchInvocation(
        'codex.cmd',
        platform: TargetPlatform.windows,
      );

      expect(invocation.executable, 'cmd.exe');
      expect(invocation.arguments, <String>[
        '/C',
        'codex.cmd app-server --listen stdio://',
      ]);
    },
  );

  test('buildCodexLaunchInvocation rejects a blank command', () {
    expect(() => buildCodexLaunchInvocation('   '), throwsFormatException);
  });

  test('CaptureOptions.parse rejects an invalid initialize timeout value', () {
    final options = CaptureOptions.parse(<String>[
      '--sanitized-output',
      'fixture.json',
      '--initialize-timeout-seconds',
      'not-an-int',
    ]);

    expect(options, isNull);
  });

  test('CaptureOptions.parse rejects an invalid read timeout value', () {
    final options = CaptureOptions.parse(<String>[
      '--sanitized-output',
      'fixture.json',
      '--read-timeout-seconds',
      'not-an-int',
    ]);

    expect(options, isNull);
  });

  test(
    'buildThreadCaptureSummary counts raw item lists without deep copying',
    () {
      final summary = buildThreadCaptureSummary(<String, dynamic>{
        'threadId': 'thread_123',
        'turns': <Map<String, Object?>>[
          <String, Object?>{
            'items': <Object?>['a', 'b'],
          },
          <String, Object?>{
            'items': <Object?>[1, 2, 3],
          },
          <String, Object?>{'items': 'not-a-list'},
        ],
      }, fallbackThreadId: 'fallback_thread');

      expect(summary['threadId'], 'thread_123');
      expect(summary['turnCount'], 3);
      expect(summary['itemCountsByTurn'], <int>[2, 3, 0]);
    },
  );

  test(
    'startCodexLaunchInvocation passes the shell invocation through unchanged',
    () async {
      String? executable;
      List<String>? arguments;
      String? capturedWorkingDirectory;

      await startCodexLaunchInvocation(
        invocation: const CodexLaunchInvocation(
          executable: 'bash',
          arguments: <String>[
            '-lc',
            r'launcher "$@" && codex app-server --listen stdio://',
          ],
        ),
        workingDirectory: '/workspace',
        processStarter:
            (nextExecutable, nextArguments, {workingDirectory}) async {
              executable = nextExecutable;
              arguments = List<String>.from(nextArguments);
              capturedWorkingDirectory = workingDirectory;
              return _FakeProcess();
            },
      );

      expect(executable, 'bash');
      expect(arguments, <String>[
        '-lc',
        r'launcher "$@" && codex app-server --listen stdio://',
      ]);
      expect(capturedWorkingDirectory, '/workspace');
    },
  );
}

final class _FakeProcess implements Process {
  @override
  int get pid => 0;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Future<int> get exitCode async => 0;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}
