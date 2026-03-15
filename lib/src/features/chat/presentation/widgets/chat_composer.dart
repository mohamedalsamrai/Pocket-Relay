import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';

class ChatComposer extends StatefulWidget {
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
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.contract.draftText);
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text == widget.contract.draftText) {
      return;
    }

    _controller.value = _controller.value.copyWith(
      text: widget.contract.draftText,
      selection: TextSelection.collapsed(
        offset: widget.contract.draftText.length,
      ),
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              controller: _controller,
              enabled: widget.contract.isTextInputEnabled,
              minLines: 1,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: widget.contract.placeholder,
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
            child:
                widget.contract.primaryAction == ChatComposerPrimaryAction.stop
                ? FilledButton.tonalIcon(
                    key: const ValueKey('stop'),
                    onPressed: widget.contract.isPrimaryActionEnabled
                        ? widget.onStop
                        : null,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop'),
                  )
                : IconButton.filled(
                    key: const ValueKey('send'),
                    onPressed: widget.contract.isPrimaryActionEnabled
                        ? widget.onSend
                        : null,
                    icon: const Icon(Icons.send_rounded),
                  ),
          ),
        ],
      ),
    );
  }
}
