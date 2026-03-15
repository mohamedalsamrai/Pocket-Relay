import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_screen_shell.dart';

class CupertinoChatScreenRenderer extends StatelessWidget {
  const CupertinoChatScreenRenderer({
    super.key,
    required this.screen,
    required this.appChrome,
    required this.transcriptRegion,
    required this.composerRegion,
  });

  final ChatScreenContract screen;
  final PreferredSizeWidget appChrome;
  final Widget transcriptRegion;
  final Widget composerRegion;

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: MaterialBasedCupertinoThemeData(materialTheme: Theme.of(context)),
      child: CupertinoPageScaffold(
        child: ChatScreenGradientBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                appChrome,
                Expanded(
                  child: Material(
                    type: MaterialType.transparency,
                    child: ChatScreenBody(
                      screen: screen,
                      transcriptRegion: transcriptRegion,
                      composerRegion: composerRegion,
                      loadingIndicator: const CupertinoActivityIndicator(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
