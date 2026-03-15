import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_draft.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_form_scope.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_presenter.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart';

class PendingUserInputRequestHost extends StatefulWidget {
  const PendingUserInputRequestHost({
    super.key,
    required this.block,
    this.onSubmit,
  });

  final CodexUserInputRequestBlock block;
  final Future<void> Function(
    String requestId,
    Map<String, List<String>> answers,
  )?
  onSubmit;

  @override
  State<PendingUserInputRequestHost> createState() =>
      _PendingUserInputRequestHostState();
}

class _PendingUserInputRequestHostState
    extends State<PendingUserInputRequestHost> {
  final _presenter = const PendingUserInputPresenter();

  @override
  Widget build(BuildContext context) {
    final scope = PendingUserInputFormScope.of(context);
    final formState = scope.stateFor(widget.block);
    final contract = _presenter.present(
      block: widget.block,
      formState: formState,
    );

    return UserInputRequestCard(
      contract: contract,
      onFieldChanged: widget.block.isResolved ? null : _handleFieldChanged,
      onSubmit: widget.onSubmit == null ? null : _handleSubmit,
    );
  }

  void _handleFieldChanged(String fieldId, String value) {
    final scope = PendingUserInputFormScope.of(context);
    scope.updateField(widget.block, fieldId, value);
    setState(() {});
  }

  Future<void> _handleSubmit() async {
    final onSubmit = widget.onSubmit;
    if (onSubmit == null) {
      return;
    }

    final scope = PendingUserInputFormScope.of(context);
    final contract = _presenter.present(
      block: widget.block,
      formState: scope.stateFor(widget.block),
    );
    if (contract.isSubmitEnabled == false) {
      return;
    }

    scope.setSubmissionState(
      widget.block,
      PendingUserInputSubmissionState.submitting,
    );
    setState(() {});

    try {
      await onSubmit(widget.block.requestId, contract.submitPayload);
    } finally {
      if (mounted) {
        scope.setSubmissionState(
          widget.block,
          PendingUserInputSubmissionState.idle,
        );
        setState(() {});
      }
    }
  }
}
