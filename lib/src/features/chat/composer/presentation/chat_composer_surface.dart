import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';

class ChatComposerSurface extends StatefulWidget {
  const ChatComposerSurface({
    super.key,
    required this.platformBehavior,
    required this.contract,
    required this.onChanged,
    required this.onSend,
    this.localImagePicker,
  });

  final PocketPlatformBehavior platformBehavior;
  final ChatComposerContract contract;
  final ValueChanged<ChatComposerDraft> onChanged;
  final Future<void> Function() onSend;
  final Future<String?> Function()? localImagePicker;

  @override
  State<ChatComposerSurface> createState() => _ChatComposerSurfaceState();
}

class _DesktopSendIntent extends Intent {
  const _DesktopSendIntent();
}

class _DesktopInsertNewlineIntent extends Intent {
  const _DesktopInsertNewlineIntent();
}

class _ChatComposerSurfaceState extends State<ChatComposerSurface> {
  static const _desktopSendIntent = _DesktopSendIntent();
  static const _desktopInsertNewlineIntent = _DesktopInsertNewlineIntent();
  static const _imageTypeGroup = XTypeGroup(
    label: 'images',
    extensions: <String>['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic'],
  );
  late final TextEditingController _controller;
  late ChatComposerDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.contract.draft.normalized();
    _controller = TextEditingController(text: _draft.text);
  }

  @override
  void didUpdateWidget(covariant ChatComposerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextDraft = widget.contract.draft.normalized();
    _draft = nextDraft;
    if (_controller.text == nextDraft.text) {
      return;
    }

    _controller.value = _controller.value.copyWith(
      text: nextDraft.text,
      selection: TextSelection.collapsed(offset: nextDraft.text.length),
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
    return _buildMaterialComposer(context);
  }

  Widget _buildMaterialComposer(BuildContext context) {
    final palette = context.pocketPalette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        child: _buildContent(
          leadingAction: _showsLocalImageAttachmentAction
              ? SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    key: const ValueKey('attach_local_image'),
                    tooltip: 'Attach image',
                    onPressed: _handleAttachLocalImageTriggered,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.image_outlined, size: 18),
                  ),
                )
              : null,
          input: _wrapInputWithKeyboardSubmit(
            context,
            TextField(
              key: const ValueKey('composer_input'),
              controller: _controller,
              minLines: 1,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              onTapOutside: (_) => _dismissKeyboard(),
              onChanged: _handleChanged,
              decoration: InputDecoration(
                hintText: widget.contract.placeholder,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          primaryAction: SizedBox(
            width: 36,
            height: 36,
            child: IconButton.filled(
              key: const ValueKey('send'),
              onPressed: _isSendActionEnabled ? _handleSendTriggered : null,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            ),
          ),
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
      ),
    );
  }

  Widget _buildContent({
    Widget? leadingAction,
    required Widget input,
    required Widget primaryAction,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.end,
  }) {
    return Row(
      key: const ValueKey('chat_composer_content_row'),
      crossAxisAlignment: crossAxisAlignment,
      children: [
        if (leadingAction != null) ...[leadingAction, const SizedBox(width: 8)],
        Expanded(child: input),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: primaryAction,
        ),
      ],
    );
  }

  Widget _wrapInputWithKeyboardSubmit(BuildContext context, Widget input) {
    if (!widget.platformBehavior.usesDesktopKeyboardSubmit) {
      return input;
    }

    return Actions(
      actions: <Type, Action<Intent>>{
        _DesktopSendIntent: CallbackAction<_DesktopSendIntent>(
          onInvoke: (_) {
            if (!_canSubmitFromKeyboard) {
              return null;
            }

            unawaited(_handleSendTriggered());
            return null;
          },
        ),
        _DesktopInsertNewlineIntent:
            CallbackAction<_DesktopInsertNewlineIntent>(
              onInvoke: (_) {
                _insertTextAtSelection('\n');
                return null;
              },
            ),
      },
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter, shift: true):
              _desktopInsertNewlineIntent,
          SingleActivator(LogicalKeyboardKey.numpadEnter, shift: true):
              _desktopInsertNewlineIntent,
          SingleActivator(LogicalKeyboardKey.enter): _desktopSendIntent,
          SingleActivator(LogicalKeyboardKey.numpadEnter): _desktopSendIntent,
        },
        child: input,
      ),
    );
  }

  bool get _canSubmitFromKeyboard {
    return _isSendActionEnabled;
  }

  bool get _showsLocalImageAttachmentAction {
    return widget.contract.allowsLocalImageAttachment &&
        widget.platformBehavior.supportsLocalConnectionMode;
  }

  bool get _isSendActionEnabled {
    return widget.contract.isSendActionEnabled &&
        _controller.text.trim().isNotEmpty;
  }

  void _handleChanged(String value) {
    _draft = _draft.copyWith(text: value).normalized();
    setState(() {});
    widget.onChanged(_draft);
  }

  Future<void> _handleSendTriggered() async {
    _dismissKeyboard();
    await widget.onSend();
  }

  Future<void> _handleAttachLocalImageTriggered() async {
    final imagePath = await _pickLocalImagePath();
    if (!mounted || imagePath == null || imagePath.trim().isEmpty) {
      return;
    }

    _draft = _draft.copyWith(text: _controller.text).normalized();
    final currentSelection = _controller.selection;
    final insertion = _draft.insertLocalImage(
      path: imagePath.trim(),
      selectionStart: currentSelection.start,
      selectionEnd: currentSelection.end,
    );
    _draft = insertion.draft;
    _controller.value = _controller.value.copyWith(
      text: _draft.text,
      selection: TextSelection.collapsed(offset: insertion.selectionOffset),
      composing: TextRange.empty,
    );
    setState(() {});
    widget.onChanged(_draft);
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _insertTextAtSelection(String insertedText) {
    final currentValue = _controller.value;
    final currentSelection = currentValue.selection;
    final selection = currentSelection.isValid
        ? currentSelection
        : TextSelection.collapsed(offset: currentValue.text.length);
    final nextText = currentValue.text.replaceRange(
      selection.start,
      selection.end,
      insertedText,
    );
    final nextOffset = selection.start + insertedText.length;

    _controller.value = currentValue.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
    _draft = _draft.copyWith(text: nextText).normalized();
    widget.onChanged(_draft);
  }

  Future<String?> _pickLocalImagePath() async {
    if (widget.localImagePicker case final picker?) {
      return picker();
    }

    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_imageTypeGroup],
    );
    return file?.path;
  }
}
