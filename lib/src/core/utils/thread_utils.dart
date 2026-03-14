String shortenThreadId(String? threadId) {
  if (threadId == null || threadId.isEmpty) {
    return 'new';
  }

  if (threadId.length <= 8) {
    return threadId;
  }

  return threadId.substring(0, 8);
}
