import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/turn_elapsed_footer.dart';

class ChatScreenGradientBackground extends StatelessWidget {
  const ChatScreenGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.backgroundTop, palette.backgroundBottom],
        ),
      ),
      child: child,
    );
  }
}

class ChatScreenBody extends StatelessWidget {
  const ChatScreenBody({
    super.key,
    required this.screen,
    required this.transcriptRegion,
    required this.composerRegion,
    required this.loadingIndicator,
    required this.onStopActiveTurn,
  });

  final ChatScreenContract screen;
  final Widget transcriptRegion;
  final Widget composerRegion;
  final Widget loadingIndicator;
  final Future<void> Function() onStopActiveTurn;

  @override
  Widget build(BuildContext context) {
    if (screen.isLoading) {
      return Center(child: loadingIndicator);
    }

    return Column(
      children: [
        Expanded(child: transcriptRegion),
        if (screen.turnIndicator case final turnIndicator?)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: TurnElapsedFooter(
              turnTimer: turnIndicator.timer,
              onStop: onStopActiveTurn,
            ),
          ),
        composerRegion,
      ],
    );
  }
}
