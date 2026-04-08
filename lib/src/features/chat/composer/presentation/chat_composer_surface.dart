import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/chat/composer/application/chat_composer_image_attachment_errors.dart';
import 'package:pocket_relay/src/features/chat/composer/application/chat_composer_image_attachment_loader.dart';
import 'package:pocket_relay/src/features/chat/composer/application/chat_composer_image_attachment_picker.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/surface/chat_composer_surface_actions.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/surface/chat_composer_surface_input.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/surface/chat_composer_surface_layout.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';

class ChatComposerSurface extends StatefulWidget {
  const ChatComposerSurface({
    super.key,
    required this.platformBehavior,
    required this.contract,
    required this.onChanged,
    required this.onSend,
    this.imageAttachmentPicker,
  });

  final PocketPlatformBehavior platformBehavior;
  final ChatComposerContract contract;
  final ValueChanged<ChatComposerDraft> onChanged;
  final Future<void> Function() onSend;
  final Future<ChatComposerImageAttachment?> Function()? imageAttachmentPicker;

  @override
  State<ChatComposerSurface> createState() => _ChatComposerSurfaceState();
}

class _ChatComposerSurfaceState extends State<ChatComposerSurface> {
  static const _imageAttachmentLoader = ChatComposerImageAttachmentLoader();
  static const _imageAttachmentPicker = ChatComposerImageAttachmentPicker();
  late final TextEditingController _controller;
  late final AtomicPlaceholderTextInputFormatter _placeholderFormatter;
  late ChatComposerDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.contract.draft.normalized();
    _placeholderFormatter = AtomicPlaceholderTextInputFormatter(
      draftProvider: () => _draft,
    );
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
    return ChatComposerSurfaceLayout(
      leadingAction: _showsLocalImageAttachmentAction
          ? ChatComposerImageAttachmentAction(
              onPressed: _handleAttachImageTriggered,
            )
          : null,
      input: _buildInputRegion(),
      primaryAction: ChatComposerSendAction(
        onPressed: _isSendActionEnabled ? _handleSendTriggered : null,
      ),
    );
  }

  Widget _buildInputRegion() {
    final attachmentSummaries = _draft.imageAttachments
        .map((attachment) => attachment.summaryLabel)
        .toList(growable: false);

    return ChatComposerSurfaceInput(
      controller: _controller,
      placeholder: widget.contract.placeholder,
      inputFormatter: _placeholderFormatter,
      onChanged: _handleChanged,
      onTapOutside: _dismissKeyboard,
      attachmentSummaries: attachmentSummaries,
      usesDesktopKeyboardSubmit:
          widget.platformBehavior.usesDesktopKeyboardSubmit,
      canSubmitFromKeyboard: _isSendActionEnabled,
      onSubmitFromKeyboard: () {
        unawaited(_handleSendTriggered());
      },
      onInsertNewlineFromKeyboard: () {
        _insertTextAtSelection('\n');
      },
    );
  }

  bool get _showsLocalImageAttachmentAction {
    return widget.contract.allowsImageAttachment;
  }

  bool get _isSendActionEnabled {
    return widget.contract.isSendActionEnabled && !_draft.isEmpty;
  }

  void _handleChanged(String value) {
    _draft = _draft.copyWith(text: value).normalized();
    if (_controller.text != _draft.text) {
      _controller.value = _controller.value.copyWith(
        text: _draft.text,
        selection: _clampSelection(_controller.selection, _draft.text.length),
        composing: TextRange.empty,
      );
    }
    setState(() {});
    widget.onChanged(_draft);
  }

  Future<void> _handleSendTriggered() async {
    _dismissKeyboard();
    await widget.onSend();
  }

  Future<void> _handleAttachImageTriggered() async {
    try {
      final imageAttachment = await _pickImageAttachment();
      if (!mounted || imageAttachment == null) {
        return;
      }

      _draft = _draft.copyWith(text: _controller.text).normalized();
      final currentSelection = _controller.selection;
      final insertion = _draft.insertImageAttachment(
        attachment: imageAttachment,
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
    } on ChatComposerImageAttachmentLoadException catch (error) {
      if (!mounted) {
        return;
      }
      _showTransientError(error.userFacingError);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showTransientError(
        ChatComposerImageAttachmentErrors.unexpected(),
        underlyingError: error,
      );
    }
  }

  void _showTransientMessage(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _showTransientError(
    PocketUserFacingError error, {
    Object? underlyingError,
  }) {
    _showTransientMessage(error.inlineMessageWithDetail(underlyingError));
  }

  Future<ChatComposerImageAttachment?> _pickImageAttachment() async {
    if (widget.imageAttachmentPicker case final picker?) {
      return picker();
    }

    final file = await _imageAttachmentPicker.pickImageFile();
    if (file == null) {
      return null;
    }

    return _imageAttachmentLoader.loadFromXFile(file);
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

    final proposedValue = currentValue.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
    _controller.value = _placeholderFormatter.formatEditUpdate(
      currentValue,
      proposedValue,
    );
    _draft = _draft.copyWith(text: _controller.text).normalized();
    widget.onChanged(_draft);
  }
}

TextSelection _clampSelection(TextSelection selection, int textLength) {
  if (!selection.isValid) {
    return TextSelection.collapsed(offset: textLength);
  }

  final baseOffset = selection.baseOffset.clamp(0, textLength);
  final extentOffset = selection.extentOffset.clamp(0, textLength);
  return TextSelection(
    baseOffset: baseOffset,
    extentOffset: extentOffset,
    affinity: selection.affinity,
    isDirectional: selection.isDirectional,
  );
}

bool _rangesIntersect(
  int leftStart,
  int leftEnd,
  int rightStart,
  int rightEnd,
) {
  return leftStart < rightEnd && rightStart < leftEnd;
}
