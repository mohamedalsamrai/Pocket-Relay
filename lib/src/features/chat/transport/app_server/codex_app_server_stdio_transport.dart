import 'dart:convert';
import 'dart:typed_data';

import 'codex_app_server_models.dart';

class CodexAppServerStdioTransport implements CodexAppServerTransport {
  CodexAppServerStdioTransport(this._process);

  final CodexAppServerProcess _process;

  @override
  Stream<String> get protocolMessages => _decodeLines(_process.stdout);

  @override
  Stream<String> get diagnostics => _decodeLines(_process.stderr);

  @override
  void sendLine(String line) {
    _process.stdin.add(Uint8List.fromList(utf8.encode(line)));
  }

  @override
  Future<void> get done => _process.done;

  @override
  CodexAppServerTransportTermination? get termination =>
      CodexAppServerTransportTermination(exitCode: _process.exitCode);

  @override
  Future<void> close() => _process.close();

  Stream<String> _decodeLines(Stream<Uint8List> stream) {
    return stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }
}
