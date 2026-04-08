import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_thread_read_fixture_sanitizer.dart';
import 'capture_live_thread_read_fixture/capture_context.dart';
import 'capture_live_thread_read_fixture/capture_options.dart';
import 'capture_live_thread_read_fixture/capture_output.dart';
import 'capture_live_thread_read_fixture/codex_launch.dart';
import 'capture_live_thread_read_fixture/json_rpc_process_client.dart';

export 'capture_live_thread_read_fixture/codex_launch.dart'
    show
        CodexLaunchInvocation,
        CodexProcessStarter,
        buildCodexLaunchInvocation,
        startCodexLaunchInvocation;

Future<void> main(List<String> args) async {
  final options = CaptureOptions.parse(args);
  if (options == null) {
    printCaptureUsage(stderr);
    exitCode = 64;
    return;
  }

  JsonRpcProcessClient? client;
  try {
    final context = await resolveCaptureContext(options);
    final invocation = buildCodexLaunchInvocation(context.codexPath);
    stderr.writeln('Launching app-server from ${context.workingDirectory}...');

    final process = await startCodexLaunchInvocation(
      invocation: invocation,
      workingDirectory: context.workingDirectory,
    );

    client = JsonRpcProcessClient(process);
    await client.initialize().timeout(
      Duration(seconds: options.initializeTimeoutSeconds),
    );

    stderr.writeln(
      'Reading thread ${context.threadId} with includeTurns=true...',
    );
    final payload = await client
        .readThread(context.threadId)
        .timeout(Duration(seconds: options.readTimeoutSeconds));
    final sanitized = CodexAppServerThreadReadFixtureSanitizer().sanitize(
      payload,
    );

    if (options.rawOutputPath case final rawOutputPath?) {
      await writeJsonFile(path: rawOutputPath, content: payload);
      stderr.writeln('Raw payload written to $rawOutputPath');
    }

    await writeJsonFile(path: options.sanitizedOutputPath, content: sanitized);
    stderr.writeln(
      'Sanitized fixture written to ${options.sanitizedOutputPath}',
    );

    stdout.writeln(
      jsonEncode(
        buildThreadCaptureSummary(payload, fallbackThreadId: context.threadId),
      ),
    );
  } on TimeoutException catch (error) {
    stderr.writeln('Capture timed out: $error');
    await _writeStderrTail(client);
    exitCode = 1;
  } on JsonRpcRemoteException catch (error) {
    stderr.writeln('Codex app-server returned an error: ${error.message}');
    if (error.data != null) {
      stderr.writeln(jsonEncode(error.data));
    }
    await _writeStderrTail(client);
    exitCode = 1;
  } on ProcessException catch (error) {
    stderr.writeln('Failed to launch Codex app-server: $error');
    exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } on Object catch (error) {
    stderr.writeln('Capture failed: $error');
    await _writeStderrTail(client);
    exitCode = 1;
  } finally {
    await client?.close();
  }
}

Future<void> _writeStderrTail(JsonRpcProcessClient? client) async {
  final stderrTail = await client?.stderrTail() ?? '';
  if (stderrTail.isEmpty) {
    return;
  }
  stderr.writeln(stderrTail);
}
