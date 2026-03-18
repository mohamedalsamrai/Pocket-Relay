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
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/theme/pocket_cupertino_theme.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';

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
  CodexAppServerClient? _ownedAppServerClient;
  late CodexAppServerClient _appServerClient;
  CodexConnectionRepository? _connectionRepository;
  CodexConnectionHandoffStore? _connectionHandoffStore;
  CodexProfileStore? _profileStore;
  CodexConversationHandoffStore? _conversationHandoffStore;
  SavedProfile? _savedProfile;
  SavedConversationHandoff? _savedConversationHandoff;
  String? _scopedConnectionId;
  CodexConnectionRepository? _scopedConnectionRepository;
  CodexConnectionHandoffStore? _scopedConnectionHandoffStore;
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
    final bootstrapDependenciesChanged =
        oldWidget.connectionRepository != widget.connectionRepository ||
        oldWidget.connectionHandoffStore != widget.connectionHandoffStore;
    if (!bootstrapDependenciesChanged &&
        oldWidget.appServerClient == widget.appServerClient) {
      return;
    }

    _bindDependencies();
    if (!bootstrapDependenciesChanged) {
      return;
    }

    setState(() {
      _resetBootstrapState();
    });
    _loadBootstrapState();
  }

  @override
  void dispose() {
    final ownedClient = _ownedAppServerClient;
    if (ownedClient != null) {
      unawaited(ownedClient.dispose());
    }
    super.dispose();
  }

  void _bindDependencies() {
    if (widget.appServerClient case final injectedClient?) {
      final ownedClient = _ownedAppServerClient;
      _ownedAppServerClient = null;
      if (ownedClient != null) {
        unawaited(ownedClient.dispose());
      }
      _appServerClient = injectedClient;
    } else {
      _appServerClient = _ownedAppServerClient ??= CodexAppServerClient();
    }

    _bindCatalogBootstrapDependencies();
  }

  Future<void> _loadBootstrapState() async {
    final loadGeneration = ++_bootstrapLoadGeneration;
    await _loadCatalogBootstrapState(loadGeneration);
  }

  @override
  Widget build(BuildContext context) {
    final savedProfile = _savedProfile;
    final savedConversationHandoff = _savedConversationHandoff;
    final platformPolicy =
        widget.platformPolicy ??
        PocketPlatformPolicy.resolve(
          chatRootPlatformPolicy: widget.chatRootPlatformPolicy,
        );

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
          savedProfile: savedProfile,
          savedConversationHandoff: savedConversationHandoff,
          profileStore: _profileStore,
          conversationHandoffStore: _conversationHandoffStore,
          appServerClient: _appServerClient,
          platformPolicy: platformPolicy,
        ),
        ),
    );
  }

  void _bindCatalogBootstrapDependencies() {
    final connectionRepository =
        widget.connectionRepository ??
        (_ownedConnectionRepository ??= SecureCodexConnectionRepository());
    _connectionRepository = connectionRepository;
    _profileStore = null;
    _conversationHandoffStore = null;

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

    _ensureScopedStores(
      connectionId: selectedConnectionId,
      connectionRepository: connectionRepository,
      connectionHandoffStore: connectionHandoffStore,
    );
    final connection = results[0] as SavedConnection;
    final handoff = results[1] as SavedConversationHandoff;

    setState(() {
      _savedProfile = SavedProfile(
        profile: connection.profile,
        secrets: connection.secrets,
      );
      _savedConversationHandoff = handoff;
    });
  }

  void _ensureScopedStores({
    required String connectionId,
    required CodexConnectionRepository connectionRepository,
    required CodexConnectionHandoffStore connectionHandoffStore,
  }) {
    final scopedProfileStore = _profileStore;
    final scopedConversationHandoffStore = _conversationHandoffStore;
    if (_scopedConnectionId == connectionId &&
        _scopedConnectionRepository == connectionRepository &&
        _scopedConnectionHandoffStore == connectionHandoffStore &&
        scopedProfileStore != null &&
        scopedConversationHandoffStore != null) {
      return;
    }

    _scopedConnectionId = connectionId;
    _scopedConnectionRepository = connectionRepository;
    _scopedConnectionHandoffStore = connectionHandoffStore;
    _profileStore = ConnectionScopedProfileStore(
      connectionId: connectionId,
      connectionRepository: connectionRepository,
    );
    _conversationHandoffStore = ConnectionScopedConversationHandoffStore(
      connectionId: connectionId,
      handoffStore: connectionHandoffStore,
    );
  }

  void _resetBootstrapState() {
    _savedProfile = null;
    _savedConversationHandoff = null;
    _scopedConnectionId = null;
    _scopedConnectionRepository = null;
    _scopedConnectionHandoffStore = null;
    _profileStore = null;
    _conversationHandoffStore = null;
  }
}

class _PocketRelayHome extends StatelessWidget {
  const _PocketRelayHome({
    required this.savedProfile,
    required this.savedConversationHandoff,
    required this.profileStore,
    required this.conversationHandoffStore,
    required this.appServerClient,
    required this.platformPolicy,
  });

  final SavedProfile? savedProfile;
  final SavedConversationHandoff? savedConversationHandoff;
  final CodexProfileStore? profileStore;
  final CodexConversationHandoffStore? conversationHandoffStore;
  final CodexAppServerClient appServerClient;
  final PocketPlatformPolicy platformPolicy;

  @override
  Widget build(BuildContext context) {
    final resolvedProfile = savedProfile;
    final resolvedConversationHandoff = savedConversationHandoff;
    final resolvedProfileStore = profileStore;
    final resolvedConversationHandoffStore = conversationHandoffStore;
    if (resolvedProfile != null &&
        resolvedConversationHandoff != null &&
        resolvedProfileStore != null &&
        resolvedConversationHandoffStore != null) {
      return ChatRootAdapter(
        profileStore: resolvedProfileStore,
        conversationHandoffStore: resolvedConversationHandoffStore,
        appServerClient: appServerClient,
        initialSavedProfile: resolvedProfile,
        initialSavedConversationHandoff: resolvedConversationHandoff,
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
