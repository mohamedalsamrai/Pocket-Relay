import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_composer_surface.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.contract,
    required this.onChanged,
    required this.onSend,
    required this.onStop,
  });

  final ChatComposerContract contract;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSend;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    return ChatComposerSurface(
      contract: contract,
      onChanged: onChanged,
      onSend: onSend,
      onStop: onStop,
      style: ChatComposerVisualStyle.material,
    );
  }
}
