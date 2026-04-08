part of 'chat_session_controller.dart';

class ChatSessionTurnCompletedEvent {
  const ChatSessionTurnCompletedEvent({required this.turnId, this.threadId});

  final String turnId;
  final String? threadId;
}
