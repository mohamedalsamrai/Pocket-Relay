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
    this.supplementalStatusRegion,
    this.laneRestartAction,
    this.onRestartLane,
  });

  final ChatScreenContract screen;
  final Widget transcriptRegion;
  final Widget composerRegion;
  final Widget loadingIndicator;
  final Future<void> Function() onStopActiveTurn;
  final Widget? supplementalStatusRegion;
  final ChatLaneRestartActionContract? laneRestartAction;
  final Future<void> Function()? onRestartLane;

  @override
  Widget build(BuildContext context) {
    if (screen.isLoading) {
      return Center(child: loadingIndicator);
    }

    return Column(
      children: [
        if (supplementalStatusRegion != null) supplementalStatusRegion!,
        Expanded(child: transcriptRegion),
        if (screen.turnIndicator != null || laneRestartAction != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: TurnElapsedFooter(
              turnTimer: screen.turnIndicator?.timer,
              onStop: onStopActiveTurn,
              laneRestartAction: laneRestartAction,
              onRestart: onRestartLane,
            ),
          ),
        composerRegion,
      ],
    );
  }
}
