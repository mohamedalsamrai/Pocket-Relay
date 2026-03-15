import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_draft.dart';

class PendingUserInputFormScope extends StatefulWidget {
  const PendingUserInputFormScope({
    super.key,
    required this.activeRequestIds,
    required this.child,
  });

  final Set<String> activeRequestIds;
  final Widget child;

  static PendingUserInputFormScopeState of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_PendingUserInputFormScopeMarker>();
    assert(
      inherited != null,
      'PendingUserInputFormScope.of() called with no scope in the widget tree.',
    );
    return inherited!.state;
  }

  @override
  State<PendingUserInputFormScope> createState() =>
      PendingUserInputFormScopeState();
}

class PendingUserInputFormScopeState extends State<PendingUserInputFormScope> {
  final _store = PendingUserInputFormStore();

  @override
  void initState() {
    super.initState();
    _store.pruneActiveRequestIds(widget.activeRequestIds);
  }

  @override
  void didUpdateWidget(covariant PendingUserInputFormScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _store.pruneActiveRequestIds(widget.activeRequestIds);
  }

  PendingUserInputFormState stateFor(CodexUserInputRequestBlock block) {
    return _store.stateFor(block);
  }

  void updateField(
    CodexUserInputRequestBlock block,
    String fieldId,
    String value,
  ) {
    _store.updateField(block, fieldId, value);
  }

  void setSubmissionState(
    CodexUserInputRequestBlock block,
    PendingUserInputSubmissionState submissionState,
  ) {
    _store.setSubmissionState(block, submissionState);
  }

  @override
  Widget build(BuildContext context) {
    return _PendingUserInputFormScopeMarker(state: this, child: widget.child);
  }
}

class _PendingUserInputFormScopeMarker extends InheritedWidget {
  const _PendingUserInputFormScopeMarker({
    required this.state,
    required super.child,
  });

  final PendingUserInputFormScopeState state;

  @override
  bool updateShouldNotify(_PendingUserInputFormScopeMarker oldWidget) {
    return identical(oldWidget.state, state) == false;
  }
}

class PendingUserInputFormStore {
  final Map<String, _PendingUserInputFormEntry> _entries =
      <String, _PendingUserInputFormEntry>{};

  PendingUserInputFormState stateFor(CodexUserInputRequestBlock block) {
    if (block.isResolved) {
      _entries.remove(block.requestId);
      return PendingUserInputFormState.initial(block: block);
    }

    final fieldIds = _fieldIdsFor(block);
    final existing = _entries[block.requestId];
    if (existing == null || !_sameFieldIds(existing.fieldIds, fieldIds)) {
      final nextState = PendingUserInputFormState.initial(block: block);
      _entries[block.requestId] = _PendingUserInputFormEntry(
        fieldIds: fieldIds,
        formState: nextState,
      );
      return nextState;
    }

    return existing.formState;
  }

  void updateField(
    CodexUserInputRequestBlock block,
    String fieldId,
    String value,
  ) {
    final entry = _entryFor(block);
    _entries[block.requestId] = entry.copyWith(
      formState: entry.formState.copyWith(
        draft: entry.formState.draft.copyWithField(fieldId, value),
      ),
    );
  }

  void setSubmissionState(
    CodexUserInputRequestBlock block,
    PendingUserInputSubmissionState submissionState,
  ) {
    final entry = _entryFor(block);
    _entries[block.requestId] = entry.copyWith(
      formState: entry.formState.copyWith(submissionState: submissionState),
    );
  }

  void pruneActiveRequestIds(Set<String> activeRequestIds) {
    _entries.removeWhere(
      (requestId, _) => activeRequestIds.contains(requestId) == false,
    );
  }

  _PendingUserInputFormEntry _entryFor(CodexUserInputRequestBlock block) {
    final current = stateFor(block);
    return _entries[block.requestId] ??
        _PendingUserInputFormEntry(
          fieldIds: _fieldIdsFor(block),
          formState: current,
        );
  }

  Set<String> _fieldIdsFor(CodexUserInputRequestBlock block) {
    if (block.questions.isEmpty) {
      return const <String>{pendingUserInputFallbackFieldId};
    }

    return block.questions.map((question) => question.id).toSet();
  }

  bool _sameFieldIds(Set<String> left, Set<String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (final fieldId in left) {
      if (right.contains(fieldId) == false) {
        return false;
      }
    }

    return true;
  }
}

class _PendingUserInputFormEntry {
  const _PendingUserInputFormEntry({
    required this.fieldIds,
    required this.formState,
  });

  final Set<String> fieldIds;
  final PendingUserInputFormState formState;

  _PendingUserInputFormEntry copyWith({
    Set<String>? fieldIds,
    PendingUserInputFormState? formState,
  }) {
    return _PendingUserInputFormEntry(
      fieldIds: fieldIds ?? this.fieldIds,
      formState: formState ?? this.formState,
    );
  }
}
