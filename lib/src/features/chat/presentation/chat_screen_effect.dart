sealed class ChatScreenEffect {
  const ChatScreenEffect();
}

final class ChatShowSnackBarEffect extends ChatScreenEffect {
  const ChatShowSnackBarEffect({required this.message});

  final String message;
}
