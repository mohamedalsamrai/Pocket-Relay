import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';

Future<ConnectionRemoteRuntimeState> probeConnectionSettingsRemoteRuntime({
  required ConnectionSettingsSubmitPayload payload,
  CodexRemoteAppServerHostProbe hostProbe =
      const CodexSshRemoteAppServerHostProbe(),
}) async {
  if (payload.profile.connectionMode != ConnectionMode.remote) {
    return const ConnectionRemoteRuntimeState.unknown();
  }

  final hostCapabilities = await hostProbe.probeHostCapabilities(
    profile: payload.profile,
    secrets: payload.secrets,
  );

  return ConnectionRemoteRuntimeState(
    hostCapability: hostCapabilities.toConnectionState(),
    server: const ConnectionRemoteServerState.unknown(),
  );
}
