import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/utils/trusted_agent_command.dart';

void main() {
  test('parses a plain executable with no fixed arguments', () {
    final command = parseTrustedAgentCommand('codex');

    expect(command.executable, 'codex');
    expect(command.arguments, isEmpty);
    expect(command.usesPathLookup, isTrue);
  });

  test('parses quoted paths and fixed arguments with spaces', () {
    final command = parseTrustedAgentCommand(
      '"~/Applications/Codex App/codex" --profile "fast lane"',
    );

    expect(command.executable, '~/Applications/Codex App/codex');
    expect(command.arguments, <String>['--profile', 'fast lane']);
    expect(command.usesPathLookup, isFalse);
  });

  test('treats escaped shell metacharacters as literal arguments', () {
    final command = parseTrustedAgentCommand(
      r'codex literal\&value literal\|x',
    );

    expect(command.executable, 'codex');
    expect(command.arguments, <String>['literal&value', 'literal|x']);
  });

  test('rejects shell operators', () {
    expect(
      () => parseTrustedAgentCommand('source /etc/profile && codex'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Shell operators'),
        ),
      ),
    );
  });

  test('rejects shell expansion syntax', () {
    expect(
      () => parseTrustedAgentCommand(r'$HOME/bin/codex'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Shell expansion'),
        ),
      ),
    );
  });

  test('rejects unmatched quoting', () {
    expect(
      () => parseTrustedAgentCommand('"codex --profile fast'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('unmatched quote or escape'),
        ),
      ),
    );
  });
}
