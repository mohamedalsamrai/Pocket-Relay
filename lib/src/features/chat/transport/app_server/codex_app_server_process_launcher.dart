import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'codex_app_server_local_process.dart';
import 'codex_app_server_models.dart';
import 'codex_app_server_ssh_process.dart';
import 'codex_app_server_stdio_transport.dart';

Future<CodexAppServerTransport> openCodexAppServerTransport({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required void Function(CodexAppServerEvent event) emitEvent,
  CodexAppServerProcessLauncher remoteLauncher = openSshCodexAppServerProcess,
  CodexAppServerProcessLauncher localLauncher = openLocalCodexAppServerProcess,
}) async {
  final process = await openCodexAppServerProcess(
    profile: profile,
    secrets: secrets,
    emitEvent: emitEvent,
    remoteLauncher: remoteLauncher,
    localLauncher: localLauncher,
  );
  return CodexAppServerStdioTransport(process);
}

Future<CodexAppServerProcess> openCodexAppServerProcess({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required void Function(CodexAppServerEvent event) emitEvent,
  CodexAppServerProcessLauncher remoteLauncher = openSshCodexAppServerProcess,
  CodexAppServerProcessLauncher localLauncher = openLocalCodexAppServerProcess,
}) {
  return switch (profile.connectionMode) {
    ConnectionMode.remote => remoteLauncher(
      profile: profile,
      secrets: secrets,
      emitEvent: emitEvent,
    ),
    ConnectionMode.local => localLauncher(
      profile: profile,
      secrets: secrets,
      emitEvent: emitEvent,
    ),
  };
}
