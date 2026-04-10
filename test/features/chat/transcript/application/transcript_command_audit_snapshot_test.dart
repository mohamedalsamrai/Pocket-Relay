import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_command_audit_snapshot.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';

void main() {
  test('mergeLifecycleSnapshot carries forward terminal input in progress', () {
    final merged = TranscriptCommandAuditSnapshot.mergeLifecycleSnapshot(
      <String, dynamic>{'status': 'inProgress'},
      <String, dynamic>{'stdin': 'y\n', 'processId': 'proc_1'},
      rawMethod: 'item/updated',
      status: TranscriptRuntimeItemStatus.inProgress,
    );

    expect(merged?['stdin'], 'y\n');
  });

  test('mergeLifecycleSnapshot preserves empty stdin wait markers', () {
    final merged = TranscriptCommandAuditSnapshot.mergeLifecycleSnapshot(
      <String, dynamic>{'status': 'inProgress'},
      <String, dynamic>{'stdin': '', 'processId': 'proc_1'},
      rawMethod: 'item/updated',
      status: TranscriptRuntimeItemStatus.inProgress,
    );

    expect(merged?['stdin'], '');
  });

  test('explicitOutputPayload treats null stream fields as unknown', () {
    expect(
      TranscriptCommandAuditSnapshot.explicitOutputPayload(
        <String, dynamic>{'stdout': null},
      ),
      isNull,
    );
    expect(
      TranscriptCommandAuditSnapshot.explicitOutputPayload(
        <String, dynamic>{'stderr': null},
      ),
      isNull,
    );
  });
}
