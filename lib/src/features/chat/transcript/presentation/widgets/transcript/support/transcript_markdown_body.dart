import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

typedef TranscriptMarkdownLinkLauncher = Future<void> Function(Uri uri);

class TranscriptMarkdownLinkLauncherScope extends InheritedWidget {
  const TranscriptMarkdownLinkLauncherScope({
    super.key,
    required this.launcher,
    required super.child,
  });

  final TranscriptMarkdownLinkLauncher launcher;

  static TranscriptMarkdownLinkLauncher of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<
              TranscriptMarkdownLinkLauncherScope
            >()
            ?.launcher ??
        _launchExternalTranscriptLink;
  }

  @override
  bool updateShouldNotify(TranscriptMarkdownLinkLauncherScope oldWidget) {
    return launcher != oldWidget.launcher;
  }
}

class TranscriptMarkdownBody extends StatelessWidget {
  const TranscriptMarkdownBody({
    super.key,
    required this.data,
    required this.styleSheet,
    this.selectable = true,
  });

  final String data;
  final MarkdownStyleSheet styleSheet;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final launcher = TranscriptMarkdownLinkLauncherScope.of(context);

    return MarkdownBody(
      data: data,
      selectable: selectable,
      styleSheet: styleSheet,
      onTapLink: (text, href, title) {
        final uri = _externalWebUri(href);
        if (uri == null) {
          return;
        }

        unawaited(_openLinkSafely(launcher, uri));
      },
    );
  }
}

Future<void> _openLinkSafely(
  TranscriptMarkdownLinkLauncher launcher,
  Uri uri,
) async {
  try {
    await launcher(uri);
  } catch (_) {
    // Link launch failures should not break transcript interaction.
  }
}

Uri? _externalWebUri(String? href) {
  if (href == null || href.trim().isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(href.trim());
  if (uri == null || !uri.hasScheme) {
    return null;
  }

  final scheme = uri.scheme.toLowerCase();
  if ((scheme != 'http' && scheme != 'https') || uri.host.isEmpty) {
    return null;
  }

  return uri;
}

Future<void> _launchExternalTranscriptLink(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
