import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_errors.dart';

void main() {
  test('send conversation changed maps to a stable chat-session code', () {
    final error = ChatSessionErrors.sendConversationChanged(
      expectedThreadId: 'thread_old',
      actualThreadId: 'thread_new',
    );

    expect(
      error.definition,
      PocketErrorCatalog.chatSessionSendConversationChanged,
    );
    expect(error.inlineMessage, contains('thread_old'));
    expect(error.inlineMessage, contains('thread_new'));
  });

  test(
    'generic send failure runtime message keeps the stable code and detail',
    () {
      final error = ChatSessionErrors.sendFailed(sessionLabel: 'remote Codex');
      final runtimeMessage = ChatSessionErrors.runtimeMessage(
        error,
        error: StateError('transport broke'),
      );

      expect(error.definition, PocketErrorCatalog.chatSessionSendFailed);
      expect(
        runtimeMessage,
        contains('[${PocketErrorCatalog.chatSessionSendFailed.code}]'),
      );
      expect(runtimeMessage, contains('Underlying error: transport broke'));
    },
  );

  test('conversation load failure maps to a stable chat-session code', () {
    final error = ChatSessionErrors.conversationLoadFailed();

    expect(
      error.definition,
      PocketErrorCatalog.chatSessionConversationLoadFailed,
    );
    expect(error.title, 'Conversation load failed');
  });

  test('approval and denial failures use distinct codes', () {
    expect(
      ChatSessionErrors.approveRequestFailed().definition,
      PocketErrorCatalog.chatSessionApproveRequestFailed,
    );
    expect(
      ChatSessionErrors.denyRequestFailed().definition,
      PocketErrorCatalog.chatSessionDenyRequestFailed,
    );
  });
}
