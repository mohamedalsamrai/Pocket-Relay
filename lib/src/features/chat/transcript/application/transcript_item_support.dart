import 'dart:convert';

import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';

class TranscriptItemSupport {
  const TranscriptItemSupport({
    TranscriptPolicySupport support = const TranscriptPolicySupport(),
  }) : _support = support;

  final TranscriptPolicySupport _support;
  static final RegExp _imagePlaceholderPattern = RegExp(r'^\[Image #\d+\]$');

  CodexCanonicalItemType itemTypeFromStreamKind(
    CodexRuntimeContentStreamKind streamKind,
  ) {
    return switch (streamKind) {
      CodexRuntimeContentStreamKind.assistantText =>
        CodexCanonicalItemType.assistantMessage,
      CodexRuntimeContentStreamKind.reasoningText ||
      CodexRuntimeContentStreamKind.reasoningSummaryText =>
        CodexCanonicalItemType.reasoning,
      CodexRuntimeContentStreamKind.planText => CodexCanonicalItemType.plan,
      CodexRuntimeContentStreamKind.commandOutput =>
        CodexCanonicalItemType.commandExecution,
      CodexRuntimeContentStreamKind.fileChangeOutput =>
        CodexCanonicalItemType.fileChange,
      _ => CodexCanonicalItemType.unknown,
    };
  }

  String? extractTextFromSnapshot(Map<String, dynamic>? snapshot) {
    if (snapshot == null) {
      return null;
    }

    final result = snapshot['result'];
    final nestedResult = result is Map<String, dynamic> ? result : null;
    return _support.stringFromCandidates(<Object?>[
      snapshot['aggregatedOutput'],
      snapshot['aggregated_output'],
      snapshot['text'],
      _textFromStructuredEntries(snapshot['summary']),
      _textFromStructuredEntries(snapshot['content']),
      snapshot['summary'],
      snapshot['review'],
      snapshot['revisedPrompt'],
      snapshot['patch'],
      snapshot['result'],
      nestedResult?['output'],
      nestedResult?['text'],
      nestedResult?['path'],
      _textFromStructuredEntries(nestedResult?['content']),
    ]);
  }

  ChatComposerDraft? extractStructuredUserMessageDraft(
    Map<String, dynamic>? snapshot,
  ) {
    final contentItems = _contentItemsFromSnapshot(snapshot);
    if (contentItems == null || contentItems.isEmpty) {
      return null;
    }

    final parsedText = _firstStructuredTextEntry(contentItems);
    final imageUrls = _remoteImageUrls(contentItems);
    if (imageUrls.isEmpty) {
      return null;
    }

    final imagePlaceholders = parsedText?.imagePlaceholders ?? const <String>[];
    if (imagePlaceholders.isEmpty &&
        parsedText != null &&
        parsedText.text.trim().isNotEmpty) {
      // Upstream can represent remote images outside the text body. Pocket Relay
      // currently needs placeholder spans to keep image attachments structured.
      return null;
    }

    final effectiveText = imagePlaceholders.isNotEmpty
        ? parsedText?.text ?? ''
        : _synthesizedImageOnlyText(imageUrls.length);
    final effectiveTextElements = imagePlaceholders.isNotEmpty
        ? parsedText?.textElements ?? const <ChatComposerTextElement>[]
        : _synthesizedImageOnlyTextElements(imageUrls.length);
    final imageAttachments = <ChatComposerImageAttachment>[
      for (var index = 0; index < imageUrls.length; index += 1)
        ChatComposerImageAttachment(
          imageUrl: imageUrls[index],
          placeholder: index < imagePlaceholders.length
              ? imagePlaceholders[index]
              : imagePlaceholder(index + 1),
        ),
    ];

    final draft = ChatComposerDraft(
      text: effectiveText,
      textElements: effectiveTextElements,
      imageAttachments: imageAttachments,
    ).normalized();
    return draft.hasStructuredDraft ? draft : null;
  }

  String? defaultLifecycleBody(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.reviewEntered => 'Codex entered review mode.',
      CodexCanonicalItemType.reviewExited => 'Codex exited review mode.',
      CodexCanonicalItemType.contextCompaction =>
        'Codex compacted the current thread context.',
      _ => null,
    };
  }

  List<dynamic>? _contentItemsFromSnapshot(Map<String, dynamic>? snapshot) {
    if (snapshot == null) {
      return null;
    }

    return _listFromCandidate(snapshot['content']);
  }

  List<dynamic>? _listFromCandidate(Object? value) {
    return value is List ? List<dynamic>.from(value) : null;
  }

  _StructuredUserTextEntry? _firstStructuredTextEntry(List<dynamic> content) {
    for (final entry in content) {
      if (entry is! Map) {
        continue;
      }

      final object = Map<String, dynamic>.from(entry);
      final type = _support.stringFromCandidates(<Object?>[object['type']]);
      final text = _stringFromCandidatesPreservingWhitespace(<Object?>[
        object['text'],
        (object['content'] as Map?)?['text'],
      ]);
      final textElements = _imageTextElements(object['text_elements']);
      if (type == 'text' ||
          (type == null && (text != null || textElements.isNotEmpty))) {
        return _StructuredUserTextEntry(
          text: text ?? '',
          textElements: textElements,
        );
      }
    }

    return null;
  }

  List<String> _remoteImageUrls(List<dynamic> content) {
    final urls = <String>[];
    for (final entry in content) {
      if (entry is! Map) {
        continue;
      }

      final object = Map<String, dynamic>.from(entry);
      final type = _support.stringFromCandidates(<Object?>[object['type']]);
      if (type != 'image') {
        continue;
      }

      final url = _stringFromCandidatesPreservingWhitespace(<Object?>[
        object['url'],
      ]);
      if (url == null || url.trim().isEmpty) {
        continue;
      }
      urls.add(url.trim());
    }
    return urls;
  }

  List<ChatComposerTextElement> _imageTextElements(Object? raw) {
    if (raw is! List) {
      return const <ChatComposerTextElement>[];
    }

    final elements = <ChatComposerTextElement>[];
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }

      final object = Map<String, dynamic>.from(entry);
      final placeholder = _support.stringFromCandidates(<Object?>[
        object['placeholder'],
      ]);
      if (placeholder == null ||
          !_imagePlaceholderPattern.hasMatch(placeholder.trim())) {
        continue;
      }

      final byteRange = object['byteRange'] is Map
          ? Map<String, dynamic>.from(object['byteRange'] as Map)
          : object['byte_range'] is Map
          ? Map<String, dynamic>.from(object['byte_range'] as Map)
          : null;
      final start = byteRange?['start'];
      final end = byteRange?['end'];
      if (start is! num || end is! num) {
        continue;
      }

      elements.add(
        ChatComposerTextElement(
          start: start.toInt(),
          end: end.toInt(),
          placeholder: placeholder.trim(),
        ),
      );
    }

    return elements;
  }

  String _synthesizedImageOnlyText(int imageCount) {
    return List<String>.generate(
      imageCount,
      (index) => imagePlaceholder(index + 1),
    ).join(' ');
  }

  List<ChatComposerTextElement> _synthesizedImageOnlyTextElements(
    int imageCount,
  ) {
    final elements = <ChatComposerTextElement>[];
    final buffer = StringBuffer();
    for (var index = 0; index < imageCount; index += 1) {
      if (index > 0) {
        buffer.write(' ');
      }
      final placeholder = imagePlaceholder(index + 1);
      final startOffset = buffer.length;
      buffer.write(placeholder);
      final endOffset = buffer.length;
      final text = buffer.toString();
      elements.add(
        ChatComposerTextElement(
          start: _utf8ByteOffset(text, startOffset),
          end: _utf8ByteOffset(text, endOffset),
          placeholder: placeholder,
        ),
      );
    }
    return elements;
  }

  int _utf8ByteOffset(String text, int codeUnitOffset) {
    final safeOffset = codeUnitOffset.clamp(0, text.length).toInt();
    return utf8.encode(text.substring(0, safeOffset)).length;
  }

  String? _stringFromCandidatesPreservingWhitespace(List<Object?> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  String? _textFromStructuredEntries(Object? value) {
    if (value is! List) {
      return null;
    }

    final textParts = <String>[];
    for (final entry in value) {
      if (entry is String && entry.isNotEmpty) {
        textParts.add(entry);
        continue;
      }

      if (entry is! Map) {
        continue;
      }

      final object = Map<String, dynamic>.from(entry);
      final text = _support.stringFromCandidates(<Object?>[
        object['text'],
        (object['content'] as Map?)?['text'],
      ]);
      if (text != null && text.isNotEmpty) {
        textParts.add(text);
      }
    }

    if (textParts.isEmpty) {
      return null;
    }
    return textParts.join('\n');
  }
}

class _StructuredUserTextEntry {
  const _StructuredUserTextEntry({
    required this.text,
    required this.textElements,
  });

  final String text;
  final List<ChatComposerTextElement> textElements;

  List<String> get imagePlaceholders => textElements
      .map((element) => element.placeholder?.trim())
      .whereType<String>()
      .where((placeholder) => placeholder.isNotEmpty)
      .toList(growable: false);
}
