import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';

export 'package:flutter/material.dart';
export 'package:flutter/services.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';

Widget buildComposerApp({
  required ChatComposerContract contract,
  TargetPlatform platform = TargetPlatform.android,
  ValueChanged<ChatComposerDraft>? onChanged,
  Future<void> Function()? onSend,
  Future<ChatComposerImageAttachment?> Function()? imageAttachmentPicker,
  bool includeOutsideTapTarget = false,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light).copyWith(platform: platform),
    home: Scaffold(
      body: Column(
        children: [
          if (includeOutsideTapTarget)
            const Expanded(
              child: SizedBox(
                key: ValueKey('outside_tap_target'),
                width: double.infinity,
              ),
            ),
          ChatComposer(
            platformBehavior: PocketPlatformBehavior.resolve(
              platform: platform,
            ),
            contract: contract,
            onChanged: onChanged ?? (_) {},
            onSend: onSend ?? () async {},
            imageAttachmentPicker: imageAttachmentPicker,
          ),
        ],
      ),
    ),
  );
}

ChatComposerContract composerContract({
  String draftText = '',
  bool isSendActionEnabled = true,
  bool allowsImageAttachment = false,
}) {
  return ChatComposerContract(
    draft: ChatComposerDraft(text: draftText),
    isSendActionEnabled: isSendActionEnabled,
    allowsImageAttachment: allowsImageAttachment,
    placeholder: 'Message Codex',
  );
}

ChatComposerImageAttachment referenceImageAttachment() {
  return const ChatComposerImageAttachment(
    imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
    displayName: 'reference.png',
  );
}

FocusNode editableTextFocusNode(WidgetTester tester) {
  return tester.widget<EditableText>(find.byType(EditableText)).focusNode;
}
