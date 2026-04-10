import 'ui_block_surface_test_support.dart';

void main() {
  group('Changed file drawer syntax highlighting', () {
    for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      final themeLabel = themeMode == ThemeMode.dark ? 'dark' : 'light';

      testWidgets(
        'renders visible Dart token colors in readable and raw patch view ($themeLabel)',
        (tester) async {
          await _openDiffDrawer(
            tester,
            block: _changedFileBlock(
              id: 'dart_$themeLabel',
              path: 'lib/syntax_probe.dart',
              addedLine:
                  'class SyntaxProbe { final int syntaxTokenValue = 314159; String hi() => "highlight-green"; } // comment-highlight',
            ),
            themeMode: themeMode,
          );

          expect(find.text('Dart'), findsWidgets);
          _expectDartSyntaxColors(tester);

          await tester.tap(find.text('Raw patch'));
          await tester.pumpAndSettle();

          expect(find.text('Readable view'), findsOneWidget);
          _expectDartSyntaxColors(tester);
        },
      );
    }

    testWidgets('maps Rhai files through the Rust drawer highlighting path', (
      tester,
    ) async {
      await _openDiffDrawer(
        tester,
        block: _changedFileBlock(
          id: 'rhai',
          path: 'scripts/syntax_probe.rhai',
          addedLine:
              'fn syntax_probe(count: i32) -> i32 { let syntaxValue = 7; println!("highlight-rhai"); syntaxValue }',
        ),
      );

      expect(find.text('Rust'), findsWidgets);
      _expectRustSyntaxColors(tester);
    });

    testWidgets('falls back cleanly for unsupported files', (tester) async {
      await _openDiffDrawer(
        tester,
        block: _changedFileBlock(
          id: 'fallback',
          path: 'notes/syntax_probe.unmapped',
          addedLine: 'plain unsupported syntax payload',
        ),
      );

      expect(
        _findCodeTextStyle(
          tester,
          lineMarker: 'plain unsupported syntax payload',
          token: 'plain unsupported syntax payload',
        )?.color,
        const Color(0xFFE5E7EB),
      );

      await tester.tap(find.text('Raw patch'));
      await tester.pumpAndSettle();

      expect(
        _findCodeTextStyle(
          tester,
          lineMarker: 'plain unsupported syntax payload',
          token: 'plain unsupported syntax payload',
        )?.color,
        const Color(0xFFE5E7EB),
      );
    });
  });
}

Future<void> _openDiffDrawer(
  WidgetTester tester, {
  required TranscriptChangedFilesBlock block,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    buildTestApp(
      themeMode: themeMode,
      child: entrySurface(block: block),
    ),
  );

  final file = block.files.single.path.split('/').last;
  await tester.tap(find.text(file));
  await tester.pumpAndSettle();
}

TranscriptChangedFilesBlock _changedFileBlock({
  required String id,
  required String path,
  required String addedLine,
}) {
  return TranscriptChangedFilesBlock(
    id: id,
    createdAt: DateTime(2026, 3, 14, 12),
    title: 'Changed files',
    files: <TranscriptChangedFile>[
      TranscriptChangedFile(path: path, additions: 1, deletions: 1),
    ],
    unifiedDiff:
        'diff --git a/$path b/$path\n'
        '--- a/$path\n'
        '+++ b/$path\n'
        '@@ -1 +1 @@\n'
        '-old syntax payload\n'
        '+$addedLine\n',
  );
}

void _expectDartSyntaxColors(WidgetTester tester) {
  const lineMarker = 'highlight-green';
  expect(
    _findCodeTextStyle(
      tester,
      lineMarker: lineMarker,
      token: 'syntaxTokenValue = ',
    )?.color,
    const Color(0xFFE5E7EB),
  );
  expect(
    _findCodeTextStyle(tester, lineMarker: lineMarker, token: 'class')?.color,
    const Color(0xFF7DD3FC),
  );
  expect(
    _findCodeTextStyle(tester, lineMarker: lineMarker, token: 'int')?.color,
    const Color(0xFFC4B5FD),
  );
  expect(
    _findCodeTextStyle(tester, lineMarker: lineMarker, token: '314159')?.color,
    const Color(0xFFFBBF24),
  );
  expect(
    _findCodeTextStyle(
      tester,
      lineMarker: lineMarker,
      token: '"highlight-green"',
    )?.color,
    const Color(0xFF86EFAC),
  );
  expect(
    _findCodeTextStyle(
      tester,
      lineMarker: lineMarker,
      token: '// comment-highlight',
    )?.color,
    const Color(0xFF94A3B8),
  );
  expect(
    _findCodeTextStyle(
      tester,
      lineMarker: lineMarker,
      token: '// comment-highlight',
    )?.fontStyle,
    FontStyle.italic,
  );
}

void _expectRustSyntaxColors(WidgetTester tester) {
  const lineMarker = 'highlight-rhai';
  expect(
    _findCodeTextStyle(
      tester,
      lineMarker: lineMarker,
      token: 'syntaxValue = ',
    )?.color,
    const Color(0xFFE5E7EB),
  );
  expect(
    _findCodeTextStyle(tester, lineMarker: lineMarker, token: 'fn')?.color,
    const Color(0xFF7DD3FC),
  );
  expect(
    _findCodeTextStyle(tester, lineMarker: lineMarker, token: 'i32')?.color,
    const Color(0xFFC4B5FD),
  );
  expect(
    _findCodeTextStyle(tester, lineMarker: lineMarker, token: '7')?.color,
    const Color(0xFFFBBF24),
  );
  expect(
    _findCodeTextStyle(
      tester,
      lineMarker: lineMarker,
      token: '"highlight-rhai"',
    )?.color,
    const Color(0xFF86EFAC),
  );
}

TextStyle? _findCodeTextStyle(
  WidgetTester tester, {
  required String lineMarker,
  required String token,
}) {
  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    final text = widget.text.toPlainText();
    if (!text.contains(lineMarker)) {
      continue;
    }

    final style = _styleForCodeToken(widget.text, token);
    if (style != null) {
      return style;
    }
  }

  return null;
}

TextStyle? _styleForCodeToken(
  InlineSpan span,
  String token, [
  TextStyle? inheritedStyle,
]) {
  if (span is! TextSpan) {
    return null;
  }

  final mergedStyle = inheritedStyle?.merge(span.style) ?? span.style;
  for (final child in span.children ?? const <InlineSpan>[]) {
    final childStyle = _styleForCodeToken(child, token, mergedStyle);
    if (childStyle != null) {
      return childStyle;
    }
  }

  if ((span.text ?? '').contains(token)) {
    return mergedStyle;
  }

  return null;
}
