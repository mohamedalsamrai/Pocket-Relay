abstract final class ConnectionWorkspaceCopy {
  static const String workspaceTitle = 'Connections';
  static const String openLanesSectionTitle = 'Open lanes';
  static const String savedSectionTitle = 'Saved';
  static const String savedConnectionsTitle = 'Saved connections';
  static const String savedConnectionsMenuLabel = savedConnectionsTitle;
  static const String mobileSavedConnectionsDescription =
      'Swipe back to an open lane or open another saved connection.';
  static const String desktopSidebarDescription =
      'Keep multiple lanes open while the rest of your saved connections stay ready to launch.';
  static const String desktopSavedConnectionsDescription =
      'Open another saved connection or return to an open lane from the sidebar.';
  static const String addConnectionAction = 'Add connection';
  static const String addConnectionProgress = 'Adding…';
  static const String openLaneAction = 'Open lane';
  static const String openingLaneAction = 'Opening…';
  static const String editAction = 'Edit';
  static const String saveProgress = 'Saving…';
  static const String deleteAction = 'Delete';
  static const String deleteProgress = 'Deleting…';
  static const String returnToOpenLaneAction = 'Return to open lane';
  static const String closeLaneAction = 'Close lane';
  static const String reconnectNoticeTitle = 'Saved settings are pending';
  static const String reconnectNoticeBody =
      'Apply the saved connection settings to reconnect this lane.';
  static const String reconnectBadge = 'Reconnect needed';
  static const String reconnectAction = 'Apply';
  static const String reconnectProgress = 'Applying…';
  static const String reconnectMenuAction = 'Apply saved settings';
  static const String reconnectMenuProgress = 'Applying saved settings…';
  static const String emptyWorkspaceTitle = 'No saved connections yet.';
  static const String emptyWorkspaceMessage =
      'Add your first connection to open a new lane.';
  static const String allSavedConnectionsOpenTitle =
      'All saved connections are already open.';
  static const String allSavedConnectionsOpenMessage =
      'Return to an open lane to keep working, or add another saved connection.';

  static String emptySavedConnectionsTitle({required bool isEmptyWorkspace}) {
    return isEmptyWorkspace
        ? emptyWorkspaceTitle
        : allSavedConnectionsOpenTitle;
  }

  static String emptySavedConnectionsMessage({required bool isEmptyWorkspace}) {
    return isEmptyWorkspace
        ? emptyWorkspaceMessage
        : allSavedConnectionsOpenMessage;
  }
}
