import 'dart:convert';

class ChatComposerDraft {
  const ChatComposerDraft({
    this.text = '',
    this.textElements = const <ChatComposerTextElement>[],
    this.localImageAttachments = const <ChatComposerLocalImageAttachment>[],
  });

  final String text;
  final List<ChatComposerTextElement> textElements;
  final List<ChatComposerLocalImageAttachment> localImageAttachments;

  bool get hasTextElements => textElements.isNotEmpty;
  bool get hasLocalImageAttachments => localImageAttachments.isNotEmpty;
  bool get hasStructuredDraft => hasTextElements || hasLocalImageAttachments;
  bool get isEmpty => text.isEmpty && !hasLocalImageAttachments;

  ChatComposerDraft copyWith({
    String? text,
    List<ChatComposerTextElement>? textElements,
    List<ChatComposerLocalImageAttachment>? localImageAttachments,
  }) {
    return ChatComposerDraft(
      text: text ?? this.text,
      textElements: textElements ?? this.textElements,
      localImageAttachments:
          localImageAttachments ?? this.localImageAttachments,
    );
  }

  ChatComposerDraft normalized() {
    if (localImageAttachments.isEmpty) {
      if (textElements.isEmpty) {
        return this;
      }
      return copyWith(textElements: const <ChatComposerTextElement>[]);
    }

    final nextAttachments = <ChatComposerLocalImageAttachment>[];
    final nextTextElements = <ChatComposerTextElement>[];
    var searchStart = 0;
    for (final attachment in localImageAttachments) {
      final placeholder = attachment.placeholder?.trim();
      if (placeholder == null || placeholder.isEmpty) {
        continue;
      }

      final startOffset = text.indexOf(placeholder, searchStart);
      if (startOffset < 0) {
        continue;
      }

      final endOffset = startOffset + placeholder.length;
      nextAttachments.add(attachment);
      nextTextElements.add(
        ChatComposerTextElement(
          start: _utf8ByteOffset(text, startOffset),
          end: _utf8ByteOffset(text, endOffset),
          placeholder: placeholder,
        ),
      );
      searchStart = endOffset;
    }

    if (_listEquals(nextAttachments, localImageAttachments) &&
        _listEquals(nextTextElements, textElements)) {
      return this;
    }

    return copyWith(
      textElements: nextTextElements,
      localImageAttachments: nextAttachments,
    );
  }

  ChatComposerDraftInsertion insertLocalImage({
    required String path,
    required int selectionStart,
    required int selectionEnd,
  }) {
    final normalizedDraft = normalized();
    final safeStart = _clampOffset(selectionStart, normalizedDraft.text.length);
    final safeEnd = _clampOffset(selectionEnd, normalizedDraft.text.length);
    final rangeStart = safeStart <= safeEnd ? safeStart : safeEnd;
    final rangeEnd = safeStart <= safeEnd ? safeEnd : safeStart;
    final nextNumber = normalizedDraft.nextLocalImagePlaceholderNumber();
    final placeholder = localImagePlaceholder(nextNumber);
    final nextText = normalizedDraft.text.replaceRange(
      rangeStart,
      rangeEnd,
      placeholder,
    );
    final nextDraft = ChatComposerDraft(
      text: nextText,
      localImageAttachments: <ChatComposerLocalImageAttachment>[
        ...normalizedDraft.localImageAttachments,
        ChatComposerLocalImageAttachment(path: path, placeholder: placeholder),
      ],
    ).normalized();

    return ChatComposerDraftInsertion(
      draft: nextDraft,
      selectionOffset: rangeStart + placeholder.length,
    );
  }

  int nextLocalImagePlaceholderNumber() {
    var maxNumber = 0;
    for (final attachment in localImageAttachments) {
      final placeholderNumber = _placeholderNumber(attachment.placeholder);
      if (placeholderNumber > maxNumber) {
        maxNumber = placeholderNumber;
      }
    }
    return maxNumber + 1;
  }

  @override
  bool operator ==(Object other) {
    return other is ChatComposerDraft &&
        other.text == text &&
        _listEquals(other.textElements, textElements) &&
        _listEquals(other.localImageAttachments, localImageAttachments);
  }

  @override
  int get hashCode => Object.hash(
    text,
    Object.hashAll(textElements),
    Object.hashAll(localImageAttachments),
  );
}

class ChatComposerTextElement {
  const ChatComposerTextElement({
    required this.start,
    required this.end,
    this.placeholder,
  });

  final int start;
  final int end;
  final String? placeholder;

  @override
  bool operator ==(Object other) {
    return other is ChatComposerTextElement &&
        other.start == start &&
        other.end == end &&
        other.placeholder == placeholder;
  }

  @override
  int get hashCode => Object.hash(start, end, placeholder);
}

class ChatComposerLocalImageAttachment {
  const ChatComposerLocalImageAttachment({
    required this.path,
    this.placeholder,
  });

  final String path;
  final String? placeholder;

  @override
  bool operator ==(Object other) {
    return other is ChatComposerLocalImageAttachment &&
        other.path == path &&
        other.placeholder == placeholder;
  }

  @override
  int get hashCode => Object.hash(path, placeholder);
}

class ChatComposerDraftInsertion {
  const ChatComposerDraftInsertion({
    required this.draft,
    required this.selectionOffset,
  });

  final ChatComposerDraft draft;
  final int selectionOffset;
}

String localImagePlaceholder(int number) => '[Image #$number]';

int _utf8ByteOffset(String text, int codeUnitOffset) {
  final safeOffset = _clampOffset(codeUnitOffset, text.length);
  return utf8.encode(text.substring(0, safeOffset)).length;
}

int _clampOffset(int offset, int textLength) {
  if (offset < 0) {
    return 0;
  }
  if (offset > textLength) {
    return textLength;
  }
  return offset;
}

int _placeholderNumber(String? placeholder) {
  if (placeholder == null) {
    return 0;
  }

  final match = RegExp(r'^\[Image #(\d+)\]$').firstMatch(placeholder.trim());
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
