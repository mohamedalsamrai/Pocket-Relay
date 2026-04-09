import 'package:flutter/material.dart';

Widget widgetbookStoryCanvas({
  required Widget child,
  double maxWidth = 860,
  AlignmentGeometry alignment = Alignment.centerLeft,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        child: SizedBox(
          width: constraints.maxWidth,
          child: Align(
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

Widget widgetbookStoryFill({required Widget child, double? maxWidth}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final availableWidth = constraints.maxWidth;
      final availableHeight = constraints.maxHeight;

      return SizedBox(
        width: availableWidth,
        height: availableHeight,
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth ?? availableWidth,
              maxHeight: availableHeight,
            ),
            child: child,
          ),
        ),
      );
    },
  );
}
