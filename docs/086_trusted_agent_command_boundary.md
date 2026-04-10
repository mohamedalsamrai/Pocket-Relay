# Trusted agent command boundary

## Decision

Pocket Relay intentionally supports a user-configurable `agentCommand`, but it
is a trusted operator execution boundary, not a general shell field.

The supported shape is:

- one executable
- optional fixed arguments
- shell-style quoting only to group a single executable token or argument token

Examples:

- `codex`
- `codex --profile turbo`
- `"~/Applications/Codex App/codex" --profile "fast lane"`

## Not supported

Pocket Relay does not treat `agentCommand` as an arbitrary shell snippet.

Unsupported patterns include:

- command chaining such as `&&`, `||`, and `;`
- pipes and redirection such as `|`, `>`, and `<`
- shell expansion such as `$HOME`, command substitution, and backticks
- setup snippets such as `source /etc/profile && codex`
- multi-line commands

If launch setup is required, create a wrapper script and point
`agentCommand` at that wrapper script plus any fixed arguments.

## Ownership

Command parsing and validation now live in one shared place:

- `lib/src/core/utils/trusted_agent_command.dart`

That parser is the source of truth for:

- local launch validation and argv construction
- remote-owner validation and argv construction
- connection-settings field validation and error copy

## Runtime behavior

### Local launch

Local app-server startup uses structured process execution:

- `Process.start(executable, [...fixedArgs, 'app-server', '--listen', 'stdio://'])`

Pocket Relay no longer wraps local launch in `bash -lc` or `cmd.exe /C` just
to interpret the configured setting.

### Remote owner launch

Remote owner startup still sends a bash script over SSH, but the configured
agent command is no longer reinterpreted through `eval`.

Instead, Pocket Relay:

- parses the configured executable and fixed arguments in Dart
- serializes them into shell-safe variables and arrays
- invokes the resolved executable directly with fixed args plus runtime args

This keeps local and remote command handling aligned on the same trust model.
