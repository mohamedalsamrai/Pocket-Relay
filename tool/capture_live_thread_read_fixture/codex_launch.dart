import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_local_process.dart';

final class CodexLaunchInvocation {
  const CodexLaunchInvocation({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;
}

typedef CodexProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

CodexLaunchInvocation buildCodexLaunchInvocation(
  String launcherCommand, {
  TargetPlatform? platform,
}) {
  final normalizedLauncherCommand = launcherCommand.trim();
  if (normalizedLauncherCommand.isEmpty) {
    throw const FormatException('Codex launch command must not be empty.');
  }

  final invocation = buildLocalCodexAppServerInvocation(
    profile: ConnectionProfile.defaults().copyWith(
      connectionMode: ConnectionMode.local,
      codexPath: normalizedLauncherCommand,
      workspaceDir: '.',
    ),
    platform: platform,
  );

  return CodexLaunchInvocation(
    executable: invocation.executable,
    arguments: invocation.arguments,
  );
}

Future<Process> startCodexLaunchInvocation({
  required CodexLaunchInvocation invocation,
  required String workingDirectory,
  CodexProcessStarter processStarter = Process.start,
}) {
  return processStarter(
    invocation.executable,
    invocation.arguments,
    workingDirectory: workingDirectory,
  );
}
