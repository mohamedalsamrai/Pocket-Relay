import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';

class ChatAppChromeTitle extends StatelessWidget {
  const ChatAppChromeTitle({super.key, required this.header});

  final ChatHeaderContract header;

  @override
  Widget build(BuildContext context) {
    return _MaterialChatAppChromeTitle(header: header);
  }
}

class ChatOverflowMenuButton extends StatelessWidget {
  const ChatOverflowMenuButton({super.key, required this.actions});

  final List<ChatChromeMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: PopupMenuButton<int>(
        tooltip: 'More actions',
        onSelected: (index) {
          final action = actions[index];
          if (!action.isEnabled) {
            return;
          }
          action.onSelected();
        },
        padding: EdgeInsets.zero,
        itemBuilder: (context) {
          return actions.indexed
              .map(
                (entry) => PopupMenuItem<int>(
                  value: entry.$1,
                  enabled: entry.$2.isEnabled,
                  child: Text(
                    entry.$2.label,
                    style: !entry.$2.isEnabled
                        ? TextStyle(color: theme.disabledColor)
                        : (entry.$2.isDestructive
                              ? TextStyle(color: theme.colorScheme.error)
                              : null),
                  ),
                ),
              )
              .toList(growable: false);
        },
        child: SizedBox(
          width: 40,
          height: 40,
          child: const Center(child: Icon(Icons.more_horiz, size: 24)),
        ),
      ),
    );
  }
}

List<ChatChromeMenuAction> buildChatChromeMenuActions({
  required ChatScreenContract screen,
  required ValueChanged<ChatScreenActionId> onScreenAction,
  List<ChatChromeMenuAction> supplementalMenuActions =
      const <ChatChromeMenuAction>[],
}) {
  return <ChatChromeMenuAction>[
    ...screen.menuActions.map(
      (action) => ChatChromeMenuAction(
        label: action.label,
        onSelected: () => onScreenAction(action.id),
        isDestructive: action.id == ChatScreenActionId.clearTranscript,
        isEnabled: action.isEnabled,
      ),
    ),
    ...supplementalMenuActions,
  ];
}

IconData chatActionIcon(ChatScreenActionContract action) {
  return switch (action.icon) {
    ChatScreenActionIcon.settings => Icons.tune,
    null => Icons.more_horiz,
  };
}

class _MaterialChatAppChromeTitle extends StatelessWidget {
  const _MaterialChatAppChromeTitle({required this.header});

  final ChatHeaderContract header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(header.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(
          header.subtitle,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
