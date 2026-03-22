part of 'codex_json_rpc_codec.dart';

class CodexJsonRpcTrackedRequest {
  const CodexJsonRpcTrackedRequest({
    required this.request,
    required this.response,
  });

  final CodexJsonRpcRequest request;
  final Future<Object?> response;
}

class CodexJsonRpcRequestTracker {
  CodexJsonRpcRequestTracker({int startingRequestId = 1})
    : _nextRequestId = startingRequestId;

  int _nextRequestId;
  final _pendingResponses = <String, Completer<Object?>>{};

  CodexJsonRpcTrackedRequest createRequest(String method, {Object? params}) {
    final request = CodexJsonRpcRequest(
      id: CodexJsonRpcId(_nextRequestId++),
      method: method,
      params: params,
    );
    final completer = Completer<Object?>();
    _pendingResponses[request.id.token] = completer;

    return CodexJsonRpcTrackedRequest(
      request: request,
      response: completer.future,
    );
  }

  bool completeResponse(CodexJsonRpcResponse response) {
    final completer = _pendingResponses.remove(response.id.token);
    if (completer == null) {
      return false;
    }

    if (response.isError) {
      completer.completeError(CodexJsonRpcRemoteException(response.error!));
    } else {
      completer.complete(response.result);
    }
    return true;
  }

  void failPending(Object error) {
    for (final completer in _pendingResponses.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pendingResponses.clear();
  }
}

class CodexJsonRpcInboundRequestStore {
  final _requests = <String, CodexJsonRpcRequest>{};

  void remember(CodexJsonRpcRequest request) {
    _requests[request.id.token] = request;
  }

  CodexJsonRpcRequest? lookup(String requestId) {
    return _requests[requestId];
  }

  CodexJsonRpcRequest? take(String requestId) {
    return _requests.remove(requestId);
  }

  void clear() {
    _requests.clear();
  }
}
