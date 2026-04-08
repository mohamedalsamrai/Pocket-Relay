part of '../agent_adapter_models.dart';

abstract class AgentAdapterEvent {
  const AgentAdapterEvent();
}

class AgentAdapterConnectedEvent extends AgentAdapterEvent {
  const AgentAdapterConnectedEvent({this.userAgent});

  final String? userAgent;
}

class AgentAdapterDisconnectedEvent extends AgentAdapterEvent {
  const AgentAdapterDisconnectedEvent({this.exitCode});

  final int? exitCode;
}

class AgentAdapterNotificationEvent extends AgentAdapterEvent {
  const AgentAdapterNotificationEvent({
    required this.method,
    required this.params,
  });

  final String method;
  final Object? params;
}

class AgentAdapterRequestEvent extends AgentAdapterEvent {
  const AgentAdapterRequestEvent({
    required this.requestId,
    required this.method,
    required this.params,
  });

  final String requestId;
  final String method;
  final Object? params;
}

class AgentAdapterDiagnosticEvent extends AgentAdapterEvent {
  const AgentAdapterDiagnosticEvent({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;
}

class AgentAdapterUnpinnedHostKeyEvent extends AgentAdapterEvent {
  const AgentAdapterUnpinnedHostKeyEvent({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
  });

  final String host;
  final int port;
  final String keyType;
  final String fingerprint;
}

class AgentAdapterSshConnectFailedEvent extends AgentAdapterEvent {
  const AgentAdapterSshConnectFailedEvent({
    required this.host,
    required this.port,
    required this.message,
    this.detail,
  });

  final String host;
  final int port;
  final String message;
  final Object? detail;
}

class AgentAdapterSshHostKeyMismatchEvent extends AgentAdapterEvent {
  const AgentAdapterSshHostKeyMismatchEvent({
    required this.host,
    required this.port,
    required this.keyType,
    required this.expectedFingerprint,
    required this.actualFingerprint,
  });

  final String host;
  final int port;
  final String keyType;
  final String expectedFingerprint;
  final String actualFingerprint;
}

class AgentAdapterSshAuthenticationFailedEvent extends AgentAdapterEvent {
  const AgentAdapterSshAuthenticationFailedEvent({
    required this.host,
    required this.port,
    required this.username,
    required this.authMode,
    required this.message,
    this.detail,
  });

  final String host;
  final int port;
  final String username;
  final AuthMode authMode;
  final String message;
  final Object? detail;
}

class AgentAdapterSshAuthenticatedEvent extends AgentAdapterEvent {
  const AgentAdapterSshAuthenticatedEvent({
    required this.host,
    required this.port,
    required this.username,
    required this.authMode,
  });

  final String host;
  final int port;
  final String username;
  final AuthMode authMode;
}

class AgentAdapterSshPortForwardStartedEvent extends AgentAdapterEvent {
  const AgentAdapterSshPortForwardStartedEvent({
    required this.host,
    required this.port,
    required this.username,
    required this.remoteHost,
    required this.remotePort,
    required this.localPort,
  });

  final String host;
  final int port;
  final String username;
  final String remoteHost;
  final int remotePort;
  final int localPort;
}

class AgentAdapterSshPortForwardFailedEvent extends AgentAdapterEvent {
  const AgentAdapterSshPortForwardFailedEvent({
    required this.host,
    required this.port,
    required this.username,
    required this.remoteHost,
    required this.remotePort,
    required this.message,
    this.detail,
  });

  final String host;
  final int port;
  final String username;
  final String remoteHost;
  final int remotePort;
  final String message;
  final Object? detail;
}
