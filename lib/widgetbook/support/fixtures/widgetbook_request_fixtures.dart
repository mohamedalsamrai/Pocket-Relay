import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/pending_user_input_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/widgetbook/support/fixtures/widgetbook_fixture_foundation.dart';

abstract final class WidgetbookRequestFixtures {
  static ChatApprovalRequestContract approvalRequest({
    bool isResolved = false,
  }) {
    return ChatApprovalRequestContract(
      id: 'approval_request',
      createdAt: WidgetbookFixtureFoundation.timestamp,
      requestId: 'req_apply_patch',
      requestType: TranscriptCanonicalRequestType.applyPatchApproval,
      title: 'Approve file edits',
      body:
          'Codex wants to update the connection settings and retry the remote launch.',
      isResolved: isResolved,
      resolutionLabel: isResolved ? 'approved' : null,
    );
  }

  static PendingUserInputContract pendingUserInput({
    bool resolved = false,
    bool submitting = false,
  }) {
    return PendingUserInputContract(
      requestId: 'user_input_review_scope',
      title: 'Need user input',
      body:
          'Choose how to continue this session before the next tool call starts.',
      isResolved: resolved,
      isSubmitting: submitting,
      isSubmitEnabled: !resolved,
      statusBadgeLabel: resolved
          ? 'submitted'
          : (submitting ? 'submitting' : 'pending'),
      submitLabel: submitting ? 'Submitting…' : 'Submit review',
      submitPayload: const <String, List<String>>{
        'mode': <String>['Retry now'],
      },
      fields: const <PendingUserInputFieldContract>[
        PendingUserInputFieldContract(
          id: 'mode',
          header: 'Action',
          prompt: 'Pick how the session should continue.',
          inputLabel: 'Action',
          value: 'Retry now',
          options: <PendingUserInputOptionContract>[
            PendingUserInputOptionContract(
              label: 'Retry now',
              description: 'Retry the remote launch immediately',
            ),
            PendingUserInputOptionContract(
              label: 'Open settings',
              description: 'Review the saved host and workspace path first',
            ),
            PendingUserInputOptionContract(
              label: 'Stop session',
              description: 'Leave the connection blocked for now',
            ),
          ],
        ),
        PendingUserInputFieldContract(
          id: 'notes',
          header: 'Notes',
          prompt: 'Add any extra context before continuing.',
          inputLabel: 'Notes',
          value:
              'The workspace path changed on the remote host after the last deploy.',
          minLines: 3,
          maxLines: 5,
        ),
      ],
    );
  }
}
