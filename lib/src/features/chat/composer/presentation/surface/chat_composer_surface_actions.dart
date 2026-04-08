import 'package:flutter/material.dart';

class ChatComposerImageAttachmentAction extends StatelessWidget {
  const ChatComposerImageAttachmentAction({super.key, required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        key: const ValueKey('attach_image'),
        tooltip: 'Attach image',
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.image_outlined, size: 18),
      ),
    );
  }
}

class ChatComposerSendAction extends StatelessWidget {
  const ChatComposerSendAction({super.key, required this.onPressed});

  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton.filled(
        key: const ValueKey('send'),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.arrow_upward_rounded, size: 18),
      ),
    );
  }
}
