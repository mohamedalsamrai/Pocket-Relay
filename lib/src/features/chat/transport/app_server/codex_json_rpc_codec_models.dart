part of 'codex_json_rpc_codec.dart';

sealed class CodexJsonRpcMessage {
  const CodexJsonRpcMessage();

  Map<String, Object?> toJson();
}

class CodexJsonRpcId {
  const CodexJsonRpcId(this.value);

  final Object value;

  factory CodexJsonRpcId.fromRaw(Object? rawValue) {
    if (rawValue is int) {
      return CodexJsonRpcId(rawValue);
    }

    if (rawValue is String) {
      return CodexJsonRpcId(rawValue);
    }

    if (rawValue is num && rawValue.isFinite && rawValue == rawValue.toInt()) {
      return CodexJsonRpcId(rawValue.toInt());
    }

    throw const FormatException(
      'JSON-RPC id must be a string or integer value.',
    );
  }

  String get token => switch (value) {
    int rawValue => 'i:$rawValue',
    String rawValue => 's:$rawValue',
    _ => 'o:$value',
  };

  String get displayValue => value.toString();
}

class CodexJsonRpcNotification extends CodexJsonRpcMessage {
  const CodexJsonRpcNotification({required this.method, this.params});

  final String method;
  final Object? params;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'method': method,
      if (params != null) 'params': params,
    };
  }
}

class CodexJsonRpcRequest extends CodexJsonRpcMessage {
  const CodexJsonRpcRequest({
    required this.id,
    required this.method,
    this.params,
  });

  final CodexJsonRpcId id;
  final String method;
  final Object? params;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id.value,
      'method': method,
      if (params != null) 'params': params,
    };
  }
}

class CodexJsonRpcError {
  const CodexJsonRpcError({required this.message, this.code, this.data});

  final String message;
  final int? code;
  final Object? data;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (code != null) 'code': code,
      'message': message,
      if (data != null) 'data': data,
    };
  }
}

class CodexJsonRpcResponse extends CodexJsonRpcMessage {
  const CodexJsonRpcResponse._({
    required this.id,
    this.result,
    this.error,
    required this.isError,
  });

  factory CodexJsonRpcResponse.success({
    required CodexJsonRpcId id,
    Object? result,
  }) {
    return CodexJsonRpcResponse._(id: id, result: result, isError: false);
  }

  factory CodexJsonRpcResponse.failure({
    required CodexJsonRpcId id,
    required CodexJsonRpcError error,
  }) {
    return CodexJsonRpcResponse._(id: id, error: error, isError: true);
  }

  final CodexJsonRpcId id;
  final Object? result;
  final CodexJsonRpcError? error;
  final bool isError;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id.value,
      if (isError) 'error': error?.toJson() else 'result': result,
    };
  }
}

class CodexJsonRpcRemoteException implements Exception {
  const CodexJsonRpcRemoteException(this.error);

  final CodexJsonRpcError error;

  @override
  String toString() {
    if (error.code == null) {
      return 'CodexJsonRpcRemoteException: ${error.message}';
    }
    return 'CodexJsonRpcRemoteException(${error.code}): ${error.message}';
  }
}

sealed class CodexJsonRpcDecodeResult {
  const CodexJsonRpcDecodeResult();
}

class CodexJsonRpcDecodedMessage extends CodexJsonRpcDecodeResult {
  const CodexJsonRpcDecodedMessage(this.message);

  final CodexJsonRpcMessage message;
}

class CodexJsonRpcMalformedMessage extends CodexJsonRpcDecodeResult {
  const CodexJsonRpcMalformedMessage({
    required this.line,
    required this.problem,
  });

  final String line;
  final String problem;
}
