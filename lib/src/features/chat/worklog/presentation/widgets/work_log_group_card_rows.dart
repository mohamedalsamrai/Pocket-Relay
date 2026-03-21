part of 'work_log_group_card.dart';

class _WorkLogEntryRow extends StatelessWidget {
  const _WorkLogEntryRow({required this.entry});

  final ChatWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      final ChatSedReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: blueAccent(Theme.of(context).brightness),
        icon: Icons.menu_book_outlined,
      ),
      final ChatCatReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: tealAccent(Theme.of(context).brightness),
        icon: Icons.description_outlined,
      ),
      final ChatHeadReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: amberAccent(Theme.of(context).brightness),
        icon: Icons.vertical_align_top,
      ),
      final ChatTailReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: pinkAccent(Theme.of(context).brightness),
        icon: Icons.vertical_align_bottom,
      ),
      final ChatGetContentReadWorkLogEntryContract readEntry =>
        _ReadWorkLogEntryRow(
          entry: readEntry,
          accent: violetAccent(Theme.of(context).brightness),
          icon: Icons.subject_outlined,
        ),
      final ChatRipgrepSearchWorkLogEntryContract searchEntry =>
        _SearchWorkLogEntryRow(
          entry: searchEntry,
          accent: tealAccent(Theme.of(context).brightness),
          icon: Icons.manage_search_outlined,
        ),
      final ChatGrepSearchWorkLogEntryContract searchEntry =>
        _SearchWorkLogEntryRow(
          entry: searchEntry,
          accent: blueAccent(Theme.of(context).brightness),
          icon: Icons.saved_search_outlined,
        ),
      final ChatSelectStringSearchWorkLogEntryContract searchEntry =>
        _SearchWorkLogEntryRow(
          entry: searchEntry,
          accent: violetAccent(Theme.of(context).brightness),
          icon: Icons.find_in_page_outlined,
        ),
      final ChatFindStrSearchWorkLogEntryContract searchEntry =>
        _SearchWorkLogEntryRow(
          entry: searchEntry,
          accent: amberAccent(Theme.of(context).brightness),
          icon: Icons.travel_explore_outlined,
        ),
      final ChatGitWorkLogEntryContract gitEntry => _GitWorkLogEntryRow(
        entry: gitEntry,
        accent: amberAccent(Theme.of(context).brightness),
        icon: Icons.source_outlined,
      ),
      final ChatCommandWaitWorkLogEntryContract waitEntry =>
        _CommandWaitWorkLogEntryRow(
          entry: waitEntry,
          accent: Theme.of(context).colorScheme.tertiary,
          icon: Icons.hourglass_top_rounded,
        ),
      final ChatCommandExecutionWorkLogEntryContract commandEntry =>
        _CommandExecutionWorkLogEntryRow(
          entry: commandEntry,
          accent: blueAccent(Theme.of(context).brightness),
          icon: Icons.terminal_outlined,
        ),
      final ChatWebSearchWorkLogEntryContract webSearchEntry =>
        _WebSearchWorkLogEntryRow(
          entry: webSearchEntry,
          accent: tealAccent(Theme.of(context).brightness),
          icon: Icons.travel_explore_outlined,
        ),
      final ChatMcpToolCallWorkLogEntryContract mcpEntry =>
        _McpToolCallWorkLogEntryRow(
          entry: mcpEntry,
          accent: mcpEntry.status == ChatMcpToolCallStatus.failed
              ? redAccent(Theme.of(context).brightness)
              : amberAccent(Theme.of(context).brightness),
          icon: Icons.extension_outlined,
        ),
      final ChatGenericWorkLogEntryContract genericEntry =>
        _GenericWorkLogEntryRow(entry: genericEntry),
    };
  }
}

class _GenericWorkLogEntryRow extends StatelessWidget {
  const _GenericWorkLogEntryRow({required this.entry});

  final ChatGenericWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ConversationCardPalette.of(context);
    final accent = workLogAccent(entry.entryKind, theme.brightness);

    return _WorkLogRowShell(
      icon: workLogIcon(entry.entryKind),
      accent: accent,
      title: entry.title,
      statusBadge: _specialCommandStatusBadge(
        theme: theme,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      details: entry.preview == null
          ? const <Widget>[]
          : <Widget>[
              Text(
                entry.preview!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 11.5,
                  height: 1.25,
                ),
              ),
            ],
    );
  }
}

class _SearchWorkLogEntryRow extends StatelessWidget {
  const _SearchWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final ChatContentSearchWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      label: entry.summaryLabel,
      titleWidget: Text.rich(
        _buildSearchQuerySpan(entry: entry, cards: cards),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      statusBadge: _specialCommandStatusBadge(
        theme: Theme.of(context),
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      details: <Widget>[
        Text(
          entry.scopeLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cards.textSecondary,
            fontSize: 11.25,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _WebSearchWorkLogEntryRow extends StatelessWidget {
  const _WebSearchWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final ChatWebSearchWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      label: entry.activityLabel,
      title: entry.queryText,
      statusBadge: entry.isRunning
          ? TranscriptBadge(
              label: 'running',
              color: tealAccent(Theme.of(context).brightness),
            )
          : null,
      details: <Widget>[
        Text(
          entry.resultSummary ?? entry.scopeLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cards.textSecondary,
            fontSize: 11.25,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _CommandWaitWorkLogEntryRow extends StatelessWidget {
  const _CommandWaitWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final ChatCommandWaitWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      label: entry.activityLabel,
      title: entry.commandText,
      statusBadge: TranscriptBadge(label: 'waiting', color: accent),
      details: entry.outputPreview == null
          ? const <Widget>[]
          : <Widget>[
              Text(
                entry.outputPreview!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 11.25,
                  height: 1.25,
                ),
              ),
            ],
    );
  }
}

class _CommandExecutionWorkLogEntryRow extends StatelessWidget {
  const _CommandExecutionWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final ChatCommandExecutionWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      label: entry.activityLabel,
      title: entry.commandText,
      statusBadge: _specialCommandStatusBadge(
        theme: Theme.of(context),
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      details: entry.outputPreview == null
          ? const <Widget>[]
          : <Widget>[
              Text(
                entry.outputPreview!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 11.25,
                  height: 1.25,
                ),
              ),
            ],
    );
  }
}

class _GitWorkLogEntryRow extends StatelessWidget {
  const _GitWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final ChatGitWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      label: entry.summaryLabel,
      title: entry.primaryLabel,
      statusBadge: _specialCommandStatusBadge(
        theme: Theme.of(context),
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      details: entry.secondaryLabel == null
          ? const <Widget>[]
          : <Widget>[
              Text(
                entry.secondaryLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 11.25,
                  height: 1.25,
                ),
              ),
            ],
    );
  }
}

class _ReadWorkLogEntryRow extends StatelessWidget {
  const _ReadWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final ChatFileReadWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      label: entry.summaryLabel,
      title: entry.fileName,
      statusBadge: _specialCommandStatusBadge(
        theme: Theme.of(context),
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      details: <Widget>[
        Text(
          entry.filePath,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cards.textSecondary,
            fontSize: 11.25,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _McpToolCallWorkLogEntryRow extends StatelessWidget {
  const _McpToolCallWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final ChatMcpToolCallWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final outcomeColor = entry.status == ChatMcpToolCallStatus.failed
        ? accent
        : cards.textSecondary;

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      title: entry.identityLabel,
      titleMonospace: true,
      details: <Widget>[
        if (entry.argumentsLabel != null)
          Text(
            entry.argumentsLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cards.textSecondary,
              fontSize: 11.25,
              height: 1.25,
              fontFamily: 'monospace',
            ),
          ),
        if (entry.outcomeLabel != null)
          Text(
            entry.outcomeLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: outcomeColor,
              fontSize: 11.25,
              height: 1.25,
            ),
          ),
      ],
    );
  }
}

TextSpan _buildSearchQuerySpan({
  required ChatContentSearchWorkLogEntryContract entry,
  required ConversationCardPalette cards,
}) {
  final segments = entry.querySegments;
  if (segments.length <= 1) {
    return TextSpan(
      text: entry.displayQueryText,
      style: TextStyle(
        color: cards.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 13.5,
        height: 1.15,
      ),
    );
  }

  final children = <InlineSpan>[];
  for (var index = 0; index < segments.length; index += 1) {
    if (index > 0) {
      children.add(
        TextSpan(
          text: ' | ',
          style: TextStyle(
            color: cards.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12.25,
            height: 1.2,
          ),
        ),
      );
    }
    children.add(
      TextSpan(
        text: segments[index],
        style: TextStyle(
          color: cards.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
          height: 1.15,
        ),
      ),
    );
  }

  return TextSpan(children: children);
}
