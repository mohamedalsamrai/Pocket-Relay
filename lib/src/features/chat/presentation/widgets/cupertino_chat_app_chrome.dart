import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';

class CupertinoChatAppChrome extends StatelessWidget
    implements PreferredSizeWidget {
  const CupertinoChatAppChrome({
    super.key,
    required this.screen,
    required this.onScreenAction,
  });

  final ChatScreenContract screen;
  final ValueChanged<ChatScreenActionId> onScreenAction;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final separatorColor = CupertinoDynamicColor.resolve(
      CupertinoColors.separator,
      context,
    );
    final titleTextStyle = CupertinoTheme.of(
      context,
    ).textTheme.navTitleTextStyle;

    return CupertinoNavigationBar(
      transitionBetweenRoutes: false,
      automaticallyImplyLeading: false,
      backgroundColor: CupertinoColors.systemBackground.withValues(alpha: 0.84),
      border: Border(bottom: BorderSide(color: separatorColor)),
      middle: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            screen.header.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleTextStyle,
          ),
          Text(
            screen.header.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...screen.toolbarActions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _ToolbarActionButton(
                action: action,
                onPressed: () => onScreenAction(action.id),
              ),
            ),
          ),
          if (screen.menuActions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                left: screen.toolbarActions.isEmpty ? 0 : 8,
              ),
              child: _MenuActionButton(
                title: screen.header.title,
                subtitle: screen.header.subtitle,
                actions: screen.menuActions,
                onSelected: onScreenAction,
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolbarActionButton extends StatelessWidget {
  const _ToolbarActionButton({required this.action, required this.onPressed});

  final ChatScreenActionContract action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final message = action.tooltip ?? action.label;
    return Tooltip(
      message: message,
      child: CupertinoButton(
        key: ValueKey<String>('cupertino_toolbar_${action.id.name}'),
        minimumSize: const Size(28, 28),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Icon(_iconForToolbarAction(action), size: 22),
      ),
    );
  }
}

class _MenuActionButton extends StatelessWidget {
  const _MenuActionButton({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.onSelected,
  });

  final String title;
  final String subtitle;
  final List<ChatScreenActionContract> actions;
  final ValueChanged<ChatScreenActionId> onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'More actions',
      child: CupertinoButton(
        key: const ValueKey('cupertino_menu_actions'),
        minimumSize: const Size(28, 28),
        padding: EdgeInsets.zero,
        onPressed: () async {
          final selected = await showCupertinoModalPopup<ChatScreenActionId>(
            context: context,
            builder: (context) {
              return CupertinoActionSheet(
                title: Text(title),
                message: Text(subtitle),
                actions: actions
                    .map(
                      (action) => CupertinoActionSheetAction(
                        isDestructiveAction:
                            action.id == ChatScreenActionId.clearTranscript,
                        onPressed: () {
                          Navigator.of(context).pop(action.id);
                        },
                        child: Text(action.label),
                      ),
                    )
                    .toList(growable: false),
                cancelButton: CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
              );
            },
          );

          if (selected != null) {
            onSelected(selected);
          }
        },
        child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
      ),
    );
  }
}

IconData _iconForToolbarAction(ChatScreenActionContract action) {
  return switch (action.icon) {
    ChatScreenActionIcon.settings => CupertinoIcons.slider_horizontal_3,
    null => CupertinoIcons.circle,
  };
}
