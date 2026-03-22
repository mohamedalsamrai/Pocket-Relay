import 'dart:async';
import 'dart:convert';

part 'codex_json_rpc_codec_models.dart';
part 'codex_json_rpc_codec_tracking.dart';

class CodexJsonRpcCodec {
  const CodexJsonRpcCodec();

  String encodeLine(CodexJsonRpcMessage message) {
    return '${jsonEncode(message.toJson())}\n';
  }

  CodexJsonRpcDecodeResult decodeLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return const CodexJsonRpcMalformedMessage(
        line: '',
        problem: 'Message line was empty.',
      );
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return CodexJsonRpcMalformedMessage(
          line: trimmed,
          problem: 'Message was not a JSON object.',
        );
      }

      final object = Map<String, Object?>.from(decoded);
      final method = object['method'];
      final hasId = object.containsKey('id');
      final hasResult = object.containsKey('result');
      final hasError = object.containsKey('error');

      if (method is String) {
        if (hasResult || hasError) {
          return CodexJsonRpcMalformedMessage(
            line: trimmed,
            problem: 'Message cannot have both method and result/error fields.',
          );
        }

        if (hasId) {
          final id = _parseId(object['id'], trimmed);
          if (id is CodexJsonRpcMalformedMessage) {
            return id;
          }
          return CodexJsonRpcDecodedMessage(
            CodexJsonRpcRequest(
              id: id as CodexJsonRpcId,
              method: method,
              params: object['params'],
            ),
          );
        }

        return CodexJsonRpcDecodedMessage(
          CodexJsonRpcNotification(method: method, params: object['params']),
        );
      }

      if (hasId) {
        if (hasResult == hasError) {
          return CodexJsonRpcMalformedMessage(
            line: trimmed,
            problem: 'Response must contain exactly one of result or error.',
          );
        }

        final id = _parseId(object['id'], trimmed);
        if (id is CodexJsonRpcMalformedMessage) {
          return id;
        }

        if (hasError) {
          final errorObject = object['error'];
          if (errorObject is! Map) {
            return CodexJsonRpcMalformedMessage(
              line: trimmed,
              problem: 'Response error payload was not an object.',
            );
          }

          final error = Map<String, Object?>.from(errorObject);
          final message = error['message'];
          if (message is! String || message.trim().isEmpty) {
            return CodexJsonRpcMalformedMessage(
              line: trimmed,
              problem: 'Response error payload was missing a message.',
            );
          }

          return CodexJsonRpcDecodedMessage(
            CodexJsonRpcResponse.failure(
              id: id as CodexJsonRpcId,
              error: CodexJsonRpcError(
                message: message,
                code: (error['code'] as num?)?.toInt(),
                data: error['data'],
              ),
            ),
          );
        }

        return CodexJsonRpcDecodedMessage(
          CodexJsonRpcResponse.success(
            id: id as CodexJsonRpcId,
            result: object['result'],
          ),
        );
      }

      return CodexJsonRpcMalformedMessage(
        line: trimmed,
        problem:
            'Message did not match request, notification, or response shape.',
      );
    } on FormatException catch (error) {
      return CodexJsonRpcMalformedMessage(
        line: trimmed,
        problem: 'Invalid JSON-RPC payload: ${error.message}',
      );
    } on Object catch (error) {
      return CodexJsonRpcMalformedMessage(
        line: trimmed,
        problem: 'Invalid JSON-RPC payload: $error',
      );
    }
  }

  Object _parseId(Object? rawValue, String line) {
    try {
      return CodexJsonRpcId.fromRaw(rawValue);
    } on FormatException catch (error) {
      return CodexJsonRpcMalformedMessage(
        line: line,
        problem: 'Invalid JSON-RPC payload: ${error.message}',
      );
    }
  }
}
