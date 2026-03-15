import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.contract,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final ChatComposerContract contract;
  final Future<void> Function() onSend;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: contract.isTextInputEnabled,
              minLines: 1,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: contract.placeholder,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: contract.primaryAction == ChatComposerPrimaryAction.stop
                ? FilledButton.tonalIcon(
                    key: const ValueKey('stop'),
                    onPressed: contract.isPrimaryActionEnabled ? onStop : null,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop'),
                  )
                : IconButton.filled(
                    key: const ValueKey('send'),
                    onPressed: contract.isPrimaryActionEnabled ? onSend : null,
                    icon: const Icon(Icons.send_rounded),
                  ),
          ),
        ],
      ),
    );
  }
}
