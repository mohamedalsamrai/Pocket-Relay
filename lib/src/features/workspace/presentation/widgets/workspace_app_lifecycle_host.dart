import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_continuity_lifecycle.dart';

class WorkspaceAppLifecycleHost extends StatefulWidget {
  const WorkspaceAppLifecycleHost({
    super.key,
    required this.onLifecycleStateChanged,
    required this.child,
  });

  final WorkspaceContinuityLifecycleStateChanged onLifecycleStateChanged;
  final Widget child;

  @override
  State<WorkspaceAppLifecycleHost> createState() =>
      _WorkspaceAppLifecycleHostState();
}

class _WorkspaceAppLifecycleHostState extends State<WorkspaceAppLifecycleHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(widget.onLifecycleStateChanged(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
