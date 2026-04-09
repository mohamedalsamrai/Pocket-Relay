import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';

abstract final class WidgetbookWorkLogFixtures {
  static ChatChangedFilesItemContract changedFilesItem({
    bool isRunning = false,
    String variant = 'mixed',
  }) {
    ChatChangedFilePresentationContract filePresentation(
      String path, {
      String? movePath,
    }) {
      return ChatChangedFilePresentationContract.fromPaths(
        path: path,
        movePath: movePath,
      );
    }

    const designDiff = ChatChangedFileDiffContract(
      id: 'diff_transcript_frame',
      file: ChatChangedFilePresentationContract(
        currentPath:
            'lib/src/features/chat/transcript/presentation/widgets/transcript/surfaces/approval_request_surface.dart',
        fileName: 'approval_request_surface.dart',
        directoryLabel:
            'lib/src/features/chat/transcript/presentation/widgets/transcript/cards',
        languageLabel: 'Dart',
        syntaxLanguage: 'dart',
      ),
      operationKind: ChatChangedFileOperationKind.modified,
      operationLabel: 'Edited',
      statusLabel: 'modified',
      stats: ChatChangedFileStatsContract(additions: 42, deletions: 11),
      lines: <ChatChangedFileDiffLineContract>[
        ChatChangedFileDiffLineContract(
          text: '@@ -1,6 +1,17 @@',
          kind: ChatChangedFileDiffLineKind.hunk,
        ),
        ChatChangedFileDiffLineContract(
          text: '+  final String blockingReason;',
          kind: ChatChangedFileDiffLineKind.addition,
        ),
        ChatChangedFileDiffLineContract(
          text: '+  final bool isDangerous;',
          kind: ChatChangedFileDiffLineKind.addition,
        ),
        ChatChangedFileDiffLineContract(
          text: '-  final String summary;',
          kind: ChatChangedFileDiffLineKind.deletion,
        ),
        ChatChangedFileDiffLineContract(
          text: '   child: PocketTranscriptFrame(...),',
          kind: ChatChangedFileDiffLineKind.context,
        ),
      ],
    );

    final createdRow = ChatChangedFileRowContract(
      id: 'changed_file_created',
      file: filePresentation('lib/src/core/ui/primitives/pocket_badge.dart'),
      operationKind: ChatChangedFileOperationKind.created,
      operationLabel: 'Created',
      stats: const ChatChangedFileStatsContract(additions: 36, deletions: 0),
      diff: const ChatChangedFileDiffContract(
        id: 'diff_created_badge',
        file: ChatChangedFilePresentationContract(
          currentPath: 'lib/src/core/ui/primitives/pocket_badge.dart',
          fileName: 'pocket_badge.dart',
          directoryLabel: 'lib/src/core/ui/primitives',
          languageLabel: 'Dart',
          syntaxLanguage: 'dart',
        ),
        operationKind: ChatChangedFileOperationKind.created,
        operationLabel: 'Created',
        statusLabel: 'created',
        stats: ChatChangedFileStatsContract(additions: 36, deletions: 0),
        lines: <ChatChangedFileDiffLineContract>[
          ChatChangedFileDiffLineContract(
            text: '+++ b/lib/src/core/ui/primitives/pocket_badge.dart',
            kind: ChatChangedFileDiffLineKind.meta,
          ),
          ChatChangedFileDiffLineContract(
            text: '+class PocketTintBadge extends StatelessWidget {',
            kind: ChatChangedFileDiffLineKind.addition,
          ),
          ChatChangedFileDiffLineContract(
            text: '+class PocketSolidBadge extends StatelessWidget {',
            kind: ChatChangedFileDiffLineKind.addition,
          ),
        ],
      ),
    );

    final modifiedRows = <ChatChangedFileRowContract>[
      ChatChangedFileRowContract(
        id: 'changed_file_1',
        file: filePresentation(
          'lib/src/features/chat/transcript/presentation/widgets/transcript/surfaces/approval_request_surface.dart',
        ),
        operationKind: ChatChangedFileOperationKind.modified,
        operationLabel: 'Edited',
        stats: const ChatChangedFileStatsContract(additions: 27, deletions: 5),
        diff: designDiff,
      ),
      ChatChangedFileRowContract(
        id: 'changed_file_2',
        file: filePresentation(
          'lib/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_unpinned_host_key_surface.dart',
        ),
        operationKind: ChatChangedFileOperationKind.modified,
        operationLabel: 'Edited',
        stats: const ChatChangedFileStatsContract(additions: 54, deletions: 9),
        diff: ChatChangedFileDiffContract(
          id: 'diff_widgetbook_fixtures',
          file: filePresentation(
            'lib/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_unpinned_host_key_surface.dart',
          ),
          operationKind: ChatChangedFileOperationKind.modified,
          operationLabel: 'Edited',
          statusLabel: 'modified',
          stats: ChatChangedFileStatsContract(additions: 54, deletions: 9),
          lines: <ChatChangedFileDiffLineContract>[
            ChatChangedFileDiffLineContract(
              text: '+  final bool canSaveFingerprint;',
              kind: ChatChangedFileDiffLineKind.addition,
            ),
            ChatChangedFileDiffLineContract(
              text: '+  final String fingerprintStatus;',
              kind: ChatChangedFileDiffLineKind.addition,
            ),
          ],
        ),
      ),
      ChatChangedFileRowContract(
        id: 'changed_file_3',
        file: filePresentation(
          'lib/src/features/connection_settings/presentation/connection_sheet.dart',
        ),
        operationKind: ChatChangedFileOperationKind.modified,
        operationLabel: 'Edited',
        stats: const ChatChangedFileStatsContract(additions: 18, deletions: 4),
      ),
    ];

    final deletedRow = ChatChangedFileRowContract(
      id: 'changed_file_deleted',
      file: filePresentation(
        'lib/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_chips.dart',
      ),
      operationKind: ChatChangedFileOperationKind.deleted,
      operationLabel: 'Deleted',
      stats: const ChatChangedFileStatsContract(additions: 0, deletions: 29),
      diff: const ChatChangedFileDiffContract(
        id: 'diff_deleted_chips',
        file: ChatChangedFilePresentationContract(
          currentPath:
              'lib/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_chips.dart',
          fileName: 'transcript_chips.dart',
          directoryLabel:
              'lib/src/features/chat/transcript/presentation/widgets/transcript/support',
          languageLabel: 'Dart',
          syntaxLanguage: 'dart',
        ),
        operationKind: ChatChangedFileOperationKind.deleted,
        operationLabel: 'Deleted',
        statusLabel: 'deleted',
        stats: ChatChangedFileStatsContract(additions: 0, deletions: 29),
        lines: <ChatChangedFileDiffLineContract>[
          ChatChangedFileDiffLineContract(
            text:
                '--- a/lib/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_chips.dart',
            kind: ChatChangedFileDiffLineKind.meta,
          ),
          ChatChangedFileDiffLineContract(
            text: '-class TranscriptBadge extends StatelessWidget {',
            kind: ChatChangedFileDiffLineKind.deletion,
          ),
          ChatChangedFileDiffLineContract(
            text: '-class InlinePulseChip extends StatelessWidget {',
            kind: ChatChangedFileDiffLineKind.deletion,
          ),
        ],
      ),
    );

    final rows = switch (variant) {
      'created' => <ChatChangedFileRowContract>[createdRow],
      'deleted' => <ChatChangedFileRowContract>[deletedRow],
      'modified' => modifiedRows,
      _ => <ChatChangedFileRowContract>[
        createdRow,
        ...modifiedRows,
        deletedRow,
      ],
    };

    return ChatChangedFilesItemContract(
      id: 'changed_files',
      title: 'Changed files',
      isRunning: isRunning,
      headerStats: ChatChangedFileStatsContract(
        additions: rows.fold<int>(0, (sum, row) => sum + row.stats.additions),
        deletions: rows.fold<int>(0, (sum, row) => sum + row.stats.deletions),
      ),
      rows: rows,
    );
  }

  static ChatWorkLogGroupItemContract workLogGroupItem() {
    return ChatWorkLogGroupItemContract(
      id: 'work_log_group',
      entries: <ChatWorkLogEntryContract>[
        ChatRipgrepSearchWorkLogEntryContract(
          id: 'work_log_rg',
          commandText: 'rg "workspaceDir|hostKey|authMode" lib/src',
          queryText: 'workspaceDir|hostKey|authMode',
          scopeTargets: <String>['lib/src'],
          exitCode: 0,
        ),
        ChatGitWorkLogEntryContract(
          id: 'work_log_git',
          commandText: 'git diff --stat',
          subcommandLabel: 'diff --stat',
          summaryLabel: 'Reviewing the latest connection-recovery edits',
          primaryLabel: 'git diff --stat',
          secondaryLabel: '3 files changed',
          exitCode: 0,
        ),
        ChatGenericWorkLogEntryContract(
          id: 'work_log_generic',
          entryKind: TranscriptWorkLogEntryKind.dynamicToolCall,
          title: 'Read saved connection details',
          preview: 'Loaded the current host, auth mode, and workspace path.',
        ),
        ChatGenericWorkLogEntryContract(
          id: 'work_log_running',
          entryKind: TranscriptWorkLogEntryKind.commandExecution,
          title: 'Retrying the remote launch',
          preview:
              'ssh relay-dev.internal "cd /workspace/Pocket-Relay && pocket-relay app-server --stdio"',
          isRunning: true,
        ),
      ],
    );
  }

  static ChatExecCommandItemContract execCommandItem({bool isRunning = true}) {
    return ChatExecCommandItemContract(
      entry: ChatCommandExecutionWorkLogEntryContract(
        id: 'exec_command_single',
        commandText:
            'ssh relay-dev.internal "cd /workspace/Pocket-Relay && pocket-relay app-server --stdio"',
        outputPreview: isRunning
            ? 'Connecting to relay-dev.internal...\nOpening remote workspace...'
            : 'Connected to relay-dev.internal.\nRemote app-server started.',
        isRunning: isRunning,
      ),
    );
  }
}
