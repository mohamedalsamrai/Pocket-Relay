import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum LiveLaneNoticeTone { informational, warning }

enum LiveLaneNoticeDismissAction { finishedWhileAway }

@immutable
class LiveLaneNoticeEntryContract {
  const LiveLaneNoticeEntryContract({
    required this.key,
    required this.title,
    required this.message,
    required this.isLoading,
    required this.tone,
    required this.icon,
    this.dismissAfterVisibleDuration,
    this.dismissAction,
  });

  final String key;
  final String title;
  final String message;
  final bool isLoading;
  final LiveLaneNoticeTone tone;
  final IconData icon;
  final Duration? dismissAfterVisibleDuration;
  final LiveLaneNoticeDismissAction? dismissAction;

  @override
  bool operator ==(Object other) {
    return other is LiveLaneNoticeEntryContract &&
        other.key == key &&
        other.title == title &&
        other.message == message &&
        other.isLoading == isLoading &&
        other.tone == tone &&
        other.icon == icon &&
        other.dismissAfterVisibleDuration == dismissAfterVisibleDuration &&
        other.dismissAction == dismissAction;
  }

  @override
  int get hashCode => Object.hash(
    key,
    title,
    message,
    isLoading,
    tone,
    icon,
    dismissAfterVisibleDuration,
    dismissAction,
  );
}

@immutable
class LiveLaneNoticeContract {
  const LiveLaneNoticeContract({required this.entries});

  final List<LiveLaneNoticeEntryContract> entries;

  bool get isEmpty => entries.isEmpty;

  LiveLaneNoticeEntryContract? get dismissibleEntry {
    for (final entry in entries) {
      if (entry.dismissAfterVisibleDuration != null &&
          entry.dismissAction != null) {
        return entry;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    return other is LiveLaneNoticeContract &&
        listEquals(other.entries, entries);
  }

  @override
  int get hashCode => Object.hashAll(entries);
}
