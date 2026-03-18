import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/codex_conversation_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/core/theme/pocket_cupertino_theme.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';
import 'package:pocket_relay/src/features/chat/presentation/connection_lane_binding.dart';

class PocketRelayApp extends StatefulWidget {
  const PocketRelayApp({
    super.key,
    this.connectionRepository,
    this.connectionHandoffStore,
    this.appServerClient,
    this.displayWakeLockController,
    this.platformPolicy,
    this.chatRootPlatformPolicy =
        const ChatRootPlatformPolicy.cupertinoFoundation(),
  });

  final CodexConnectionRepository? connectionRepository;
  final CodexConnectionHandoffStore? connectionHandoffStore;
  final CodexAppServerClient? appServerClient;
  final DisplayWakeLockController? displayWakeLockController;
  final PocketPlatformPolicy? platformPolicy;
  final ChatRootPlatformPolicy chatRootPlatformPolicy;

  @override
  State<PocketRelayApp> createState() => _PocketRelayAppState();
}

class _PocketRelayAppState extends State<PocketRelayApp> {
  CodexConnectionRepository? _ownedConnectionRepository;
  CodexConnectionHandoffStore? _ownedConnectionHandoffStore;
  CodexConnectionRepository? _ownedConnectionHandoffStoreRepository;
  CodexConnectionRepository? _connectionRepository;
  CodexConnectionHandoffStore? _connectionHandoffStore;
  ConnectionLaneBinding? _laneBinding;
  int _bootstrapLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _bindDependencies();
    _loadBootstrapState();
  }

  @override
  void didUpdateWidget(covariant PocketRelayApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    final laneDependenciesChanged =
        oldWidget.connectionRepository != widget.connectionRepository ||
        oldWidget.connectionHandoffStore != widget.connectionHandoffStore ||
        oldWidget.appServerClient != widget.appServerClient ||
        oldWidget.platformPolicy != widget.platformPolicy ||
        oldWidget.chatRootPlatformPolicy != widget.chatRootPlatformPolicy;
    if (!laneDependenciesChanged) {
      return;
    }

    _bindDependencies();
    setState(_resetBootstrapState);
    _loadBootstrapState();
  }

  @override
  void dispose() {
    _laneBinding?.dispose();
    super.dispose();
  }

  PocketPlatformPolicy get _resolvedPlatformPolicy {
    return widget.platformPolicy ??
        PocketPlatformPolicy.resolve(
          chatRootPlatformPolicy: widget.chatRootPlatformPolicy,
        );
  }

  void _bindDependencies() {
    final connectionRepository =
        widget.connectionRepository ??
        (_ownedConnectionRepository ??= SecureCodexConnectionRepository());
    _connectionRepository = connectionRepository;

    if (widget.connectionHandoffStore case final injectedHandoffStore?) {
      _connectionHandoffStore = injectedHandoffStore;
      return;
    }

    final ownedHandoffStore = _ownedConnectionHandoffStore;
    if (ownedHandoffStore == null ||
        _ownedConnectionHandoffStoreRepository != connectionRepository) {
      _ownedConnectionHandoffStore = SecureCodexConnectionHandoffStore(
        connectionRepository: connectionRepository,
      );
      _ownedConnectionHandoffStoreRepository = connectionRepository;
    }
    _connectionHandoffStore = _ownedConnectionHandoffStore;
  }

  Future<void> _loadBootstrapState() async {
    final loadGeneration = ++_bootstrapLoadGeneration;
    await _loadCatalogBootstrapState(loadGeneration);
  }

  Future<void> _loadCatalogBootstrapState(int loadGeneration) async {
    final connectionRepository = _connectionRepository;
    final connectionHandoffStore = _connectionHandoffStore;
    if (connectionRepository == null || connectionHandoffStore == null) {
      return;
    }

    final catalog = await connectionRepository.loadCatalog();
    if (!mounted ||
        loadGeneration != _bootstrapLoadGeneration ||
        connectionRepository != _connectionRepository ||
        connectionHandoffStore != _connectionHandoffStore) {
      return;
    }
    if (catalog.isEmpty) {
      throw StateError(
        'PocketRelayApp requires at least one saved connection during catalog bootstrap.',
      );
    }

    final selectedConnectionId = catalog.orderedConnectionIds.first;
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      connectionRepository.loadConnection(selectedConnectionId),
      connectionHandoffStore.load(selectedConnectionId),
    ]);
    if (!mounted ||
        loadGeneration != _bootstrapLoadGeneration ||
        connectionRepository != _connectionRepository ||
        connectionHandoffStore != _connectionHandoffStore) {
      return;
    }

    final connection = results[0] as SavedConnection;
    final handoff = results[1] as SavedConversationHandoff;
    final savedProfile = SavedProfile(
      profile: connection.profile,
      secrets: connection.secrets,
    );
    final nextLaneBinding = ConnectionLaneBinding(
      connectionId: selectedConnectionId,
      profileStore: ConnectionScopedProfileStore(
        connectionId: selectedConnectionId,
        connectionRepository: connectionRepository,
      ),
      conversationHandoffStore: ConnectionScopedConversationHandoffStore(
        connectionId: selectedConnectionId,
        handoffStore: connectionHandoffStore,
      ),
      appServerClient: widget.appServerClient ?? CodexAppServerClient(),
      initialSavedProfile: savedProfile,
      initialSavedConversationHandoff: handoff,
      supportsLocalConnectionMode:
          _resolvedPlatformPolicy.supportsLocalConnectionMode,
      ownsAppServerClient: widget.appServerClient == null,
    );

    final previousLaneBinding = _laneBinding;
    setState(() {
      _laneBinding = nextLaneBinding;
    });
    previousLaneBinding?.dispose();
  }

  void _resetBootstrapState() {
    final previousLaneBinding = _laneBinding;
    _laneBinding = null;
    previousLaneBinding?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platformPolicy = _resolvedPlatformPolicy;

    return MaterialApp(
      title: 'Pocket Relay',
      debugShowCheckedModeBanner: false,
      theme: buildPocketTheme(Brightness.light),
      darkTheme: buildPocketTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: DisplayWakeLockHost(
        displayWakeLockController:
            widget.displayWakeLockController ??
            const WakelockPlusDisplayWakeLockController(),
        supportsWakeLock: platformPolicy.supportsWakeLock,
        child: _PocketRelayHome(
          laneBinding: _laneBinding,
          platformPolicy: platformPolicy,
        ),
      ),
    );
  }
}

class _PocketRelayHome extends StatelessWidget {
  const _PocketRelayHome({
    required this.laneBinding,
    required this.platformPolicy,
  });

  final ConnectionLaneBinding? laneBinding;
  final PocketPlatformPolicy platformPolicy;

  @override
  Widget build(BuildContext context) {
    final resolvedLaneBinding = laneBinding;
    if (resolvedLaneBinding != null) {
      return ChatRootAdapter(
        laneBinding: resolvedLaneBinding,
        platformPolicy: platformPolicy,
      );
    }

    return _PocketRelayBootstrapShell(
      screenShell: platformPolicy.regionPolicy.screenShell,
    );
  }
}

class _PocketRelayBootstrapShell extends StatelessWidget {
  const _PocketRelayBootstrapShell({required this.screenShell});

  final ChatRootScreenShellRenderer screenShell;

  @override
  Widget build(BuildContext context) {
    return switch (screenShell) {
      ChatRootScreenShellRenderer.flutter => const _FlutterBootstrapShell(),
      ChatRootScreenShellRenderer.cupertino => const _CupertinoBootstrapShell(),
    };
  }
}

class _FlutterBootstrapShell extends StatelessWidget {
  const _FlutterBootstrapShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _BootstrapBackground(
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _CupertinoBootstrapShell extends StatelessWidget {
  const _CupertinoBootstrapShell();

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;

    return CupertinoTheme(
      data: buildPocketCupertinoTheme(Theme.of(context)),
      child: CupertinoPageScaffold(
        backgroundColor: palette.backgroundTop,
        child: const _BootstrapBackground(
          child: Center(child: CupertinoActivityIndicator()),
        ),
      ),
    );
  }
}

class _BootstrapBackground extends StatelessWidget {
  const _BootstrapBackground({required this.child});

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
