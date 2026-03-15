import 'package:pocket_relay/src/features/chat/presentation/chat_screen_effect.dart';

class ChatScreenEffectMapper {
  const ChatScreenEffectMapper();

  ChatScreenEffect mapSnackBarMessage(String message) {
    return ChatShowSnackBarEffect(message: message);
  }
}
