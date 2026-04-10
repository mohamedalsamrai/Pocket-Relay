import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';

class ChatComposerDraftHost extends ChangeNotifier {
  ChatComposerDraft _draft = const ChatComposerDraft();
  int _revision = 0;
  bool _isDisposed = false;

  ChatComposerDraft get draft => _draft;
  int get revision => _revision;
  bool get isDisposed => _isDisposed;

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

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    super.dispose();
  }
}
