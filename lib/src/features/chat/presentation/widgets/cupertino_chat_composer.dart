import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_composer_surface.dart';

class CupertinoChatComposerRegion extends StatelessWidget {
  const CupertinoChatComposerRegion({
    super.key,
    required this.composer,
    required this.onComposerDraftChanged,
    required this.onSendPrompt,
    required this.onStopActiveTurn,
  });

  final ChatComposerContract composer;
  final ValueChanged<String> onComposerDraftChanged;
  final Future<void> Function() onSendPrompt;
  final Future<void> Function() onStopActiveTurn;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: CupertinoChatComposer(
          contract: composer,
          onChanged: onComposerDraftChanged,
          onSend: onSendPrompt,
          onStop: onStopActiveTurn,
        ),
      ),
    );
  }
}

class CupertinoChatComposer extends StatelessWidget {
  const CupertinoChatComposer({
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
      style: ChatComposerVisualStyle.cupertino,
    );
  }
}
