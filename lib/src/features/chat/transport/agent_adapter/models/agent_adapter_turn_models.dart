part of '../agent_adapter_models.dart';

class AgentAdapterTurn {
  const AgentAdapterTurn({required this.threadId, required this.turnId});

  final String threadId;
  final String turnId;
}

class AgentAdapterTurnInput {
  const AgentAdapterTurnInput({
    this.text = '',
    this.textElements = const <AgentAdapterTextElement>[],
    this.images = const <AgentAdapterImageInput>[],
  });

  const AgentAdapterTurnInput.text(String text)
    : this(text: text, textElements: const <AgentAdapterTextElement>[]);

  final String text;
  final List<AgentAdapterTextElement> textElements;
  final List<AgentAdapterImageInput> images;

  bool get hasText => text.trim().isNotEmpty || textElements.isNotEmpty;
  bool get hasImages => images.any((image) => image.url.trim().isNotEmpty);
  bool get isEmpty => !hasText && !hasImages;

  @override
  bool operator ==(Object other) {
    return other is AgentAdapterTurnInput &&
        other.text == text &&
        _listEquals(other.textElements, textElements) &&
        _listEquals(other.images, images);
  }

  @override
  int get hashCode =>
      Object.hash(text, Object.hashAll(textElements), Object.hashAll(images));
}

class AgentAdapterImageInput {
  const AgentAdapterImageInput({required this.url});

  final String url;

  @override
  bool operator ==(Object other) {
    return other is AgentAdapterImageInput && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}

class AgentAdapterTextElement {
  const AgentAdapterTextElement({
    required this.start,
    required this.end,
    this.placeholder,
  });

  final int start;
  final int end;
  final String? placeholder;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'byteRange': <String, Object?>{'start': start, 'end': end},
      if (placeholder != null) 'placeholder': placeholder,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is AgentAdapterTextElement &&
        other.start == start &&
        other.end == end &&
        other.placeholder == placeholder;
  }

  @override
  int get hashCode => Object.hash(start, end, placeholder);
}

enum AgentAdapterElicitationAction { accept, decline, cancel }
