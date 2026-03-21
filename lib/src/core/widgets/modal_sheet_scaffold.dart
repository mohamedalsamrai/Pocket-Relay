import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';

class ModalSheetScaffold extends StatelessWidget {
  const ModalSheetScaffold({
    super.key,
    required this.header,
    required this.body,
    this.headerPadding = const EdgeInsets.fromLTRB(20, 20, 20, 16),
    this.bodyPadding,
    this.showDivider = true,
    this.bodyIsScrollable = true,
  });

  final Widget header;
  final Widget body;
  final EdgeInsetsGeometry headerPadding;
  final EdgeInsetsGeometry? bodyPadding;
  final bool showDivider;
  final bool bodyIsScrollable;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final resolvedBodyPadding =
        bodyPadding ??
        EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        );

    return Material(
      color: palette.sheetBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: headerPadding, child: header),
            if (showDivider) const Divider(height: 1),
            Expanded(
              child: bodyIsScrollable
                  ? SingleChildScrollView(
                      padding: resolvedBodyPadding,
                      child: body,
                    )
                  : body,
            ),
          ],
        ),
      ),
    );
  }
}

class ModalSheetDragHandle extends StatelessWidget {
  const ModalSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 48,
        height: 5,
        decoration: BoxDecoration(
          color: context.pocketPalette.dragHandle,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
