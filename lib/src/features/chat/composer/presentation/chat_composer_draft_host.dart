import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';

class ChatComposerDraftHost extends ChangeNotifier {
  ChatComposerDraft _draft = const ChatComposerDraft();
  int _revision = 0;

  ChatComposerDraft get draft => _draft;
  int get revision => _revision;

  void updateDraft(ChatComposerDraft draft) {
    if (_draft == draft) {
      return;
    }

    _draft = draft;
    _revision += 1;
    notifyListeners();
  }

  void updateText(String text) {
    updateDraft(_draft.copyWith(text: text));
  }

  void clear() {
    updateDraft(const ChatComposerDraft());
  }

  void reset() {
    clear();
  }
}
