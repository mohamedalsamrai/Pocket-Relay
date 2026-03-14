import 'package:flutter/material.dart';

import 'package:codex_pocket/src/core/storage/codex_profile_store.dart';
import 'package:codex_pocket/src/features/chat/presentation/chat_screen.dart';
import 'package:codex_pocket/src/features/chat/services/ssh_codex_service.dart';

class CodexPocketApp extends StatelessWidget {
  const CodexPocketApp({super.key, this.profileStore, this.remoteService});

  final CodexProfileStore? profileStore;
  final SshCodexService? remoteService;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Codex Pocket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF4EFE5),
        textTheme: ThemeData.light(useMaterial3: true).textTheme.apply(
          bodyColor: const Color(0xFF1C1917),
          displayColor: const Color(0xFF1C1917),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF4EFE5),
          foregroundColor: const Color(0xFF1C1917),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
        ),
      ),
      home: ChatScreen(
        profileStore: profileStore ?? SecureCodexProfileStore(),
        remoteService: remoteService ?? SshCodexService(),
      ),
    );
  }
}
