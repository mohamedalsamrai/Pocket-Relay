import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_renderer.dart';

ConnectionSettingsRenderer connectionSettingsRendererFor(
  PocketPlatformPolicy platformPolicy,
) {
  return switch (platformPolicy.regionPolicy.rendererFor(
    ChatRootRegion.settingsOverlay,
  )) {
    ChatRootRegionRenderer.flutter => ConnectionSettingsRenderer.material,
    ChatRootRegionRenderer.cupertino => ConnectionSettingsRenderer.cupertino,
  };
}
