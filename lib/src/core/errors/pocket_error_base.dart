import 'package:pocket_relay/src/core/errors/pocket_error_detail_formatter.dart';

enum PocketErrorDomain {
  connectionLifecycle,
  chatSession,
  chatComposer,
  connectionSettings,
  appBootstrap,
  deviceCapability,
}

final class PocketErrorDefinition {
  const PocketErrorDefinition({
    required this.code,
    required this.domain,
    required this.meaning,
  });

  final String code;
  final PocketErrorDomain domain;
  final String meaning;
}

final class PocketUserFacingError {
  const PocketUserFacingError({
    required this.definition,
    required this.title,
    required this.message,
    this.underlyingDetail,
  });

  final PocketErrorDefinition definition;
  final String title;
  final String message;
  final String? underlyingDetail;

  String get formattedMessage => PocketErrorDetailFormatter.composeMessage(
    message: message,
    underlyingDetail: underlyingDetail,
  );

  String get inlineMessage {
    final normalizedTitle = title.trim();
    final normalizedMessage = formattedMessage.trim();
    if (normalizedTitle.isEmpty) {
      return '[${definition.code}] $normalizedMessage';
    }
    if (normalizedMessage.isEmpty) {
      return '[${definition.code}] $normalizedTitle';
    }
    return '[${definition.code}] $normalizedTitle. $normalizedMessage';
  }

  String get bodyWithCode => '[${definition.code}] ${formattedMessage.trim()}';

  PocketUserFacingError withUnderlyingDetail(String? detail) {
    final normalizedDetail = detail?.trim();
    if ((underlyingDetail ?? '') == (normalizedDetail ?? '')) {
      return this;
    }
    return PocketUserFacingError(
      definition: definition,
      title: title,
      message: message,
      underlyingDetail: normalizedDetail,
    );
  }

  PocketUserFacingError withNormalizedUnderlyingError(
    Object? error, {
    bool stripRemoteOwnerControlFailure = false,
  }) {
    final detail = PocketErrorDetailFormatter.uniqueUnderlyingDetail(
      existingText: inlineMessage,
      error: error,
      stripRemoteOwnerControlFailure: stripRemoteOwnerControlFailure,
    );
    if (detail == null) {
      return this;
    }
    return withUnderlyingDetail(detail);
  }

  String inlineMessageWithDetail(Object? error) {
    return withNormalizedUnderlyingError(error).inlineMessage;
  }
}
