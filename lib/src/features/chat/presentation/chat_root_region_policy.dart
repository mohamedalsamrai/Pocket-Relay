enum ChatRootRegion { appChrome, transcript, composer, settingsOverlay }

enum ChatRootRegionRenderer { flutter }

class ChatRootRegionPolicy {
  const ChatRootRegionPolicy({
    required this.appChrome,
    required this.transcript,
    required this.composer,
    required this.settingsOverlay,
  });

  const ChatRootRegionPolicy.allFlutter()
    : this(
        appChrome: ChatRootRegionRenderer.flutter,
        transcript: ChatRootRegionRenderer.flutter,
        composer: ChatRootRegionRenderer.flutter,
        settingsOverlay: ChatRootRegionRenderer.flutter,
      );

  final ChatRootRegionRenderer appChrome;
  final ChatRootRegionRenderer transcript;
  final ChatRootRegionRenderer composer;
  final ChatRootRegionRenderer settingsOverlay;

  ChatRootRegionRenderer rendererFor(ChatRootRegion region) {
    return switch (region) {
      ChatRootRegion.appChrome => appChrome,
      ChatRootRegion.transcript => transcript,
      ChatRootRegion.composer => composer,
      ChatRootRegion.settingsOverlay => settingsOverlay,
    };
  }
}
