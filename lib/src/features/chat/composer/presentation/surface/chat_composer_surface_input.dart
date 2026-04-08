import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/surface/chat_composer_surface_attachments.dart';

class ChatComposerSurfaceInput extends StatelessWidget {
  const ChatComposerSurfaceInput({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.inputFormatter,
    required this.onChanged,
    required this.onTapOutside,
    required this.attachmentSummaries,
    required this.usesDesktopKeyboardSubmit,
    required this.canSubmitFromKeyboard,
    required this.onSubmitFromKeyboard,
    required this.onInsertNewlineFromKeyboard,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputFormatter inputFormatter;
  final ValueChanged<String> onChanged;
  final VoidCallback onTapOutside;
  final List<String> attachmentSummaries;
  final bool usesDesktopKeyboardSubmit;
  final bool canSubmitFromKeyboard;
  final VoidCallback onSubmitFromKeyboard;
  final VoidCallback onInsertNewlineFromKeyboard;

  @override
  Widget build(BuildContext context) {
    final input = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const ValueKey('composer_input'),
          controller: controller,
          minLines: 1,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          onTapOutside: (_) => onTapOutside(),
          inputFormatters: <TextInputFormatter>[inputFormatter],
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: placeholder,
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        if (attachmentSummaries.isNotEmpty) ...[
          const SizedBox(height: 8),
          ChatComposerAttachmentSummaryList(labels: attachmentSummaries),
        ],
      ],
    );

    if (!usesDesktopKeyboardSubmit) {
      return input;
    }

    return _DesktopKeyboardSubmit(
      canSubmit: canSubmitFromKeyboard,
      onSubmit: onSubmitFromKeyboard,
      onInsertNewline: onInsertNewlineFromKeyboard,
      child: input,
    );
  }
}

class AtomicPlaceholderTextInputFormatter extends TextInputFormatter {
  AtomicPlaceholderTextInputFormatter({required this.draftProvider});

  final ChatComposerDraft Function() draftProvider;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text == newValue.text) {
      return newValue;
    }

    final placeholderSpans = draftProvider().normalized().placeholderSpans();
    if (placeholderSpans.isEmpty) {
      return newValue;
    }

    final editDelta = _TextEditDelta.fromValues(oldValue.text, newValue.text);
    if (editDelta.isInsertionOnly) {
      final containingSpan = placeholderSpans.where(
        (span) => span.containsOffset(editDelta.oldStart),
      );
      if (containingSpan.isNotEmpty) {
        final span = containingSpan.first;
        final adjustedText = oldValue.text.replaceRange(
          span.end,
          span.end,
          editDelta.insertedText,
        );
        final nextOffset = span.end + editDelta.insertedText.length;
        return newValue.copyWith(
          text: adjustedText,
          selection: TextSelection.collapsed(offset: nextOffset),
          composing: TextRange.empty,
        );
      }
      return newValue;
    }

    final intersectedSpans = placeholderSpans
        .where(
          (span) => _rangesIntersect(
            editDelta.oldStart,
            editDelta.oldEnd,
            span.start,
            span.end,
          ),
        )
        .toList(growable: false);
    if (intersectedSpans.isEmpty) {
      return newValue;
    }

    final expandedStart = intersectedSpans.first.start < editDelta.oldStart
        ? intersectedSpans.first.start
        : editDelta.oldStart;
    final expandedEnd = intersectedSpans.last.end > editDelta.oldEnd
        ? intersectedSpans.last.end
        : editDelta.oldEnd;
    final adjustedText = oldValue.text.replaceRange(
      expandedStart,
      expandedEnd,
      editDelta.insertedText,
    );
    final nextOffset = expandedStart + editDelta.insertedText.length;
    return newValue.copyWith(
      text: adjustedText,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
  }
}

class _DesktopKeyboardSubmit extends StatelessWidget {
  const _DesktopKeyboardSubmit({
    required this.canSubmit,
    required this.onSubmit,
    required this.onInsertNewline,
    required this.child,
  });

  static const _desktopSendIntent = _DesktopSendIntent();
  static const _desktopInsertNewlineIntent = _DesktopInsertNewlineIntent();

  final bool canSubmit;
  final VoidCallback onSubmit;
  final VoidCallback onInsertNewline;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        _DesktopSendIntent: CallbackAction<_DesktopSendIntent>(
          onInvoke: (_) {
            if (!canSubmit) {
              return null;
            }

            onSubmit();
            return null;
          },
        ),
        _DesktopInsertNewlineIntent:
            CallbackAction<_DesktopInsertNewlineIntent>(
              onInvoke: (_) {
                onInsertNewline();
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
        child: child,
      ),
    );
  }
}

class _DesktopSendIntent extends Intent {
  const _DesktopSendIntent();
}

class _DesktopInsertNewlineIntent extends Intent {
  const _DesktopInsertNewlineIntent();
}

class _TextEditDelta {
  const _TextEditDelta({
    required this.oldStart,
    required this.oldEnd,
    required this.insertedText,
  });

  factory _TextEditDelta.fromValues(String oldText, String newText) {
    var prefixLength = 0;
    final minLength = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefixLength < minLength &&
        oldText.codeUnitAt(prefixLength) == newText.codeUnitAt(prefixLength)) {
      prefixLength += 1;
    }

    var oldSuffixStart = oldText.length;
    var newSuffixStart = newText.length;
    while (oldSuffixStart > prefixLength &&
        newSuffixStart > prefixLength &&
        oldText.codeUnitAt(oldSuffixStart - 1) ==
            newText.codeUnitAt(newSuffixStart - 1)) {
      oldSuffixStart -= 1;
      newSuffixStart -= 1;
    }

    return _TextEditDelta(
      oldStart: prefixLength,
      oldEnd: oldSuffixStart,
      insertedText: newText.substring(prefixLength, newSuffixStart),
    );
  }

  final int oldStart;
  final int oldEnd;
  final String insertedText;

  bool get isInsertionOnly => oldStart == oldEnd && insertedText.isNotEmpty;
}

bool _rangesIntersect(
  int leftStart,
  int leftEnd,
  int rightStart,
  int rightEnd,
) {
  return leftStart < rightEnd && rightStart < leftEnd;
}
