import 'dart:async';
import 'dart:math' as math;

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_agent_adapter_bridge.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';

part 'fake_client/fake_codex_app_server_client_state.dart';
part 'fake_client/fake_codex_app_server_client_session_ops.dart';
part 'fake_client/fake_codex_app_server_client_turn_ops.dart';

class FakeCodexAppServerClient extends CodexAppServerClient
    with
        _FakeCodexAppServerClientState,
        _FakeCodexAppServerClientSessionOps,
        _FakeCodexAppServerClientTurnOps {
  FakeCodexAppServerClient()
    : super(
        transportOpener:
            ({required profile, required secrets, required emitEvent}) async {
              throw UnimplementedError(
                'The fake app-server client never opens a transport.',
              );
            },
      );
}
