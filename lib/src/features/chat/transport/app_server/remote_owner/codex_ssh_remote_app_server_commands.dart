part of '../codex_app_server_remote_owner_ssh.dart';

@visibleForTesting
String buildSshRemoteHostCapabilityProbeCommand({
  required ConnectionProfile profile,
}) {
  final command =
      '''
${_buildRequestedCodexShellFunctions(requestedCodex: profile.codexPath)}
tmux_status=1
if command -v tmux >/dev/null 2>&1; then
  tmux_status=0
fi
workspace_status=1
if cd ${shellEscape(profile.workspaceDir.trim())} >/dev/null 2>&1; then
  workspace_status=0
fi
codex_status=1
if [ "\$workspace_status" = "0" ] && run_requested_codex app-server --help >/dev/null 2>&1; then
  codex_status=0
fi
printf '__pocket_relay_capabilities__ tmux=%s workspace=%s codex=%s\\n' "\$tmux_status" "\$workspace_status" "\$codex_status"
''';
  return 'bash -lc ${shellEscape(command)}';
}

String buildPocketRelayRemoteOwnerSessionName({required String ownerId}) {
  final normalized = ownerId.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(ownerId, 'ownerId', 'must not be empty');
  }
  final sanitized = normalized
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final suffix = sanitized.isEmpty ? 'owner' : sanitized;
  return 'pocket-relay-$suffix';
}

String buildPocketRelayRemoteOwnerLogFilePath({required String sessionName}) {
  final normalized = sessionName.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(sessionName, 'sessionName', 'must not be empty');
  }
  return '/tmp/$normalized.log';
}

String _buildPocketRelayRemoteOwnerLogShellFunctions() {
  return '''
resolve_pocket_relay_log_dir() {
  if [ -n "\${XDG_RUNTIME_DIR-}" ] && [ -d "\${XDG_RUNTIME_DIR-}" ] && [ -w "\${XDG_RUNTIME_DIR-}" ]; then
    printf '%s' "\$XDG_RUNTIME_DIR/pocket-relay"
    return 0
  fi

  if [ -n "\${HOME-}" ] && [ -d "\${HOME-}" ]; then
    cache_root="\$HOME/.cache"
    if { [ -d "\$cache_root" ] && [ -w "\$cache_root" ]; } || { [ ! -e "\$cache_root" ] && [ -w "\$HOME" ]; }; then
      printf '%s' "\$cache_root/pocket-relay"
      return 0
    fi
  fi

  uid_suffix=\$(id -u 2>/dev/null | tr -cd '0-9')
  if [ -z "\$uid_suffix" ]; then
    uid_suffix=unknown
  fi
  printf '%s' "/tmp/pocket-relay-\$uid_suffix"
}

resolve_pocket_relay_log_file() {
  session_name="\$1"
  printf '%s/%s.log' "\$(resolve_pocket_relay_log_dir)" "\$session_name"
}

ensure_pocket_relay_log_dir() {
  log_dir=\$(resolve_pocket_relay_log_dir)
  previous_umask=\$(umask)
  if [ -z "\$previous_umask" ]; then
    previous_umask=022
  fi
  umask 077
  if mkdir -p "\$log_dir"; then
    status=0
  else
    status=\$?
  fi
  chmod 700 "\$log_dir" 2>/dev/null || true
  umask "\$previous_umask"
  return "\$status"
}
''';
}

@visibleForTesting
List<int> buildPocketRelayRemoteOwnerPortCandidates({
  required String ownerId,
  int candidateCount = 8,
}) {
  final normalized = ownerId.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(ownerId, 'ownerId', 'must not be empty');
  }
  if (candidateCount <= 0) {
    throw ArgumentError.value(
      candidateCount,
      'candidateCount',
      'must be greater than zero',
    );
  }

  const minPort = 42000;
  const portRange = 20000;
  final basePort = minPort + (_fnv1a32(normalized) % portRange);
  final seenPorts = <int>{};
  final ports = <int>[];
  var offset = 0;
  while (ports.length < candidateCount) {
    final port = minPort + ((basePort - minPort + offset) % portRange);
    if (seenPorts.add(port)) {
      ports.add(port);
    }
    offset += 1;
  }
  return ports;
}

int _fnv1a32(String value) {
  const offsetBasis = 0x811C9DC5;
  const prime = 0x01000193;
  var hash = offsetBasis;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * prime) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

String _buildRequestedCodexShellFunctions({required String requestedCodex}) {
  final normalizedRequestedCodex = requestedCodex.trim();
  return '''
${_buildRemoteBinaryPathPrelude()}
requested_codex=${shellEscape(normalizedRequestedCodex)}

requested_codex_requires_eval() {
  [[ "\$requested_codex" == *[[:space:]]* || "\$requested_codex" == */* ]]
}

resolve_requested_codex() {
  if [ -z "\$requested_codex" ]; then
    return 1
  fi

  if requested_codex_requires_eval; then
    printf '%s' "\$requested_codex"
    return 0
  fi

  if command -v "\$requested_codex" >/dev/null 2>&1; then
    command -v "\$requested_codex"
    return 0
  fi

  for candidate in "\$HOME/.local/bin/\$requested_codex" "\$HOME/bin/\$requested_codex" "/usr/local/bin/\$requested_codex" "/opt/homebrew/bin/\$requested_codex" "/usr/bin/\$requested_codex" "/bin/\$requested_codex"; do
    if [ -x "\$candidate" ]; then
      printf '%s' "\$candidate"
      return 0
    fi
  done

  return 1
}

run_requested_codex() {
  resolved_codex=\$(resolve_requested_codex) || return 127
  if requested_codex_requires_eval; then
    quoted_args=
    for arg in "\$@"; do
      printf -v quoted_args '%s %q' "\$quoted_args" "\$arg"
    done
    eval "\$resolved_codex\$quoted_args"
    return \$?
  fi
  "\$resolved_codex" "\$@"
}
''';
}

String _buildRemoteBinaryPathPrelude() {
  return '''
PATH="\$HOME/.local/bin:\$HOME/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:\$PATH"
export PATH
''';
}

@visibleForTesting
String buildSshRemoteOwnerInspectCommand({
  required String sessionName,
  required String workspaceDir,
}) {
  final command =
      '''
session_name=${shellEscape(sessionName)}
expected_workspace=${shellEscape(workspaceDir.trim())}
${_buildRemoteBinaryPathPrelude()}
${_buildPocketRelayRemoteOwnerLogShellFunctions()}
log_file=\$(resolve_pocket_relay_log_file "\$session_name")

encode_log_tail() {
  if [ ! -f "\$log_file" ]; then
    return 0
  fi
  tail -n 40 "\$log_file" 2>/dev/null | base64 | tr -d '\\n'
}

print_result() {
  status="\$1"
  pid="\$2"
  host="\$3"
  port="\$4"
  detail="\$5"
  if [ "\$status" = "running" ]; then
    log_b64=
  else
    log_b64=\$(encode_log_tail)
  fi
  printf '__pocket_relay_owner__ status=%s pid=%s host=%s port=%s detail=%s log_b64=%s\\n' "\$status" "\$pid" "\$host" "\$port" "\$detail" "\$log_b64"
}

resolved_process_pid=
resolved_process_args=

resolve_app_server_process() {
  current_pid="\$1"
  depth=0

  while [ -n "\$current_pid" ] && [ "\$current_pid" != "0" ] && [ "\$depth" -lt 6 ]; do
    current_args=\$(ps -p "\$current_pid" -o args= 2>/dev/null | head -n 1)
    if [ -z "\$current_args" ]; then
      return 1
    fi

    if [[ "\$current_args" =~ app-server ]]; then
      resolved_process_pid="\$current_pid"
      resolved_process_args="\$current_args"
      return 0
    fi

    child_pids=\$(ps -o pid= --ppid "\$current_pid" 2>/dev/null | awk 'NF { gsub(/^[[:space:]]+|[[:space:]]+\$/, ""); print }')
    child_count=\$(printf '%s\\n' "\$child_pids" | sed '/^\$/d' | wc -l | tr -d '[:space:]')
    if [ "\$child_count" != "1" ]; then
      return 1
    fi

    current_pid=\$(printf '%s\\n' "\$child_pids" | sed -n '1p')
    depth=\$((depth + 1))
  done

  return 1
}

if ! command -v tmux >/dev/null 2>&1; then
  print_result unhealthy "" "" "" tmux_unavailable
  exit 0
fi

if ! tmux has-session -t "\$session_name" 2>/dev/null; then
  print_result missing "" "" "" session_missing
  exit 0
fi

pane_pid=\$(tmux list-panes -t "\$session_name" -F '#{pane_pid}' 2>/dev/null | head -n 1 | tr -d '[:space:]')
pane_path=\$(tmux display-message -p -t "\$session_name" '#{pane_current_path}' 2>/dev/null | head -n 1)

if [ -z "\$pane_pid" ] || [ "\$pane_pid" = "0" ]; then
  print_result stopped "" "" "" pane_missing
  exit 0
fi

if [ -n "\$expected_workspace" ]; then
  if ! cd "\$expected_workspace" >/dev/null 2>&1; then
    print_result unhealthy "\$pane_pid" "" "" expected_workspace_unavailable
    exit 0
  fi
  expected_workspace_real=\$(pwd -P)
  pane_path_real=\$pane_path
  if [ -n "\$pane_path" ] && cd "\$pane_path" >/dev/null 2>&1; then
    pane_path_real=\$(pwd -P)
  fi
  if [ "\$pane_path_real" != "\$expected_workspace_real" ]; then
    print_result unhealthy "\$pane_pid" "" "" workspace_mismatch
    exit 0
  fi
fi

if ! resolve_app_server_process "\$pane_pid"; then
  print_result stopped "\$pane_pid" "" "" process_missing
  exit 0
fi

pane_pid="\$resolved_process_pid"
process_args="\$resolved_process_args"

listen_host=
port=
if [[ "\$process_args" =~ --listen[[:space:]]+ws://([^:[:space:]]+):([0-9]+) ]]; then
  listen_host="\${BASH_REMATCH[1]}"
  port="\${BASH_REMATCH[2]}"
else
  print_result stopped "\$pane_pid" "" "" listen_url_missing
  exit 0
fi

health_host="\$listen_host"
if [ "\$health_host" = "0.0.0.0" ]; then
  health_host=127.0.0.1
fi

http_status=
if exec 3<>"/dev/tcp/\$health_host/\$port" 2>/dev/null; then
  printf 'GET /readyz HTTP/1.1\\r\\nHost: %s\\r\\nConnection: close\\r\\n\\r\\n' "\$health_host" >&3
  response=\$(cat <&3 || true)
  exec 3<&-
  exec 3>&-
  if [[ "\$response" == HTTP/*" 200"* ]]; then
    http_status=200
  fi
fi

if [ "\$http_status" = "200" ]; then
  print_result running "\$pane_pid" "\$health_host" "\$port" ready
else
  print_result unhealthy "\$pane_pid" "\$health_host" "\$port" ready_check_failed
fi
''';
  return 'bash -lc ${shellEscape(command)}';
}

@visibleForTesting
String buildSshRemoteOwnerStartCommand({
  required String sessionName,
  required String workspaceDir,
  required String codexPath,
  required int port,
}) {
  final tmuxCommand =
      '''
${_buildRequestedCodexShellFunctions(requestedCodex: codexPath)}
${_buildPocketRelayRemoteOwnerLogShellFunctions()}
ensure_pocket_relay_log_dir
log_file=\$(resolve_pocket_relay_log_file ${shellEscape(sessionName)})
rm -f "\$log_file"
run_requested_codex app-server --listen ws://127.0.0.1:$port >>"\$log_file" 2>&1
status=\$?
echo "pocket-relay: codex app-server exited with status \$status" >>"\$log_file"
exit "\$status"
''';
  final paneCommand = 'exec bash -lc ${shellEscape(tmuxCommand)}';
  final command =
      '''
set -euo pipefail
session_name=${shellEscape(sessionName)}
workspace_dir=${shellEscape(workspaceDir.trim())}
${_buildRemoteBinaryPathPrelude()}

if ! command -v tmux >/dev/null 2>&1; then
  echo 'tmux is not available on the remote host.' >&2
  exit 1
fi

if tmux has-session -t "\$session_name" 2>/dev/null; then
  echo "Managed tmux owner already exists: \$session_name" >&2
  exit 2
fi

pane_id=\$(tmux new-session -d -P -F '#{pane_id}' -s "\$session_name" -c "\$workspace_dir")
tmux respawn-pane -k -t "\$pane_id" ${shellEscape(paneCommand)}
''';
  return 'bash -lc ${shellEscape(command)}';
}

@visibleForTesting
String buildSshRemoteOwnerStopCommand({required String sessionName}) {
  final command =
      '''
session_name=${shellEscape(sessionName)}
${_buildRemoteBinaryPathPrelude()}
${_buildPocketRelayRemoteOwnerLogShellFunctions()}
log_file=\$(resolve_pocket_relay_log_file "\$session_name")
if ! command -v tmux >/dev/null 2>&1; then
  rm -f "\$log_file"
  exit 0
fi
if tmux has-session -t "\$session_name" 2>/dev/null; then
  tmux kill-session -t "\$session_name"
fi
rm -f "\$log_file"
''';
  return 'bash -lc ${shellEscape(command)}';
}
