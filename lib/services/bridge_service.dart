import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

/// WebSocket bridge to VPS Kimi Code CLI sessions.
class BridgeService {
  WebSocketChannel? _channel;
  final _controller = StreamController<BridgeEvent>.broadcast();
  String? _vpsUrl;
  bool _connected = false;
  Timer? _heartbeat;
  StreamSubscription? _sub;

  Stream<BridgeEvent> get events => _controller.stream;
  bool get isConnected => _connected;

  /// True when running on HTTPS web and trying insecure ws:// (browsers block this).
  static bool isMixedContentBlocked(String url) {
    if (!kIsWeb) return false;
    final pageHttps = Uri.base.scheme == 'https';
    final wsInsecure = url.startsWith('ws://');
    return pageHttps && wsInsecure;
  }

  Future<void> connect(String url) async {
    await disconnect();
    _vpsUrl = url;

    if (isMixedContentBlocked(url)) {
      final msg =
          'Browser blocked insecure WebSocket.\n\n'
          'This page is HTTPS (GitHub Pages) but the bridge is ws://.\n'
          'Browsers refuse mixed content.\n\n'
          'Fix: open the app over HTTP on the VPS, or use wss:// with TLS.\n'
          'Temporary: http://85.121.148.62:9876/ (after web is hosted there).';
      _connected = false;
      _controller.add(BridgeEvent(type: BridgeEventType.error, data: {'message': msg}));
      throw Exception(msg);
    }

    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);

      // Wait until server greets us (or timeout / error)
      final ready = Completer<void>();
      Timer? timeout;

      _sub = _channel!.stream.listen(
        (data) {
          try {
            final map = jsonDecode(data as String) as Map<String, dynamic>;
            final event = BridgeEvent.fromJson(map);
            if (!_connected &&
                (event.type == BridgeEventType.connected ||
                    event.type == BridgeEventType.pong ||
                    event.type == BridgeEventType.sessionCreated ||
                    event.type == BridgeEventType.sessionList)) {
              _connected = true;
              if (!ready.isCompleted) ready.complete();
            }
            _controller.add(event);
          } catch (e) {
            debugPrint('Bridge parse error: $e');
          }
        },
        onError: (e) {
          _connected = false;
          final msg = e.toString();
          _controller.add(BridgeEvent(type: BridgeEventType.error, data: {'message': msg}));
          if (!ready.isCompleted) ready.completeError(e);
        },
        onDone: () {
          _connected = false;
          _controller.add(BridgeEvent(type: BridgeEventType.disconnected));
          _heartbeat?.cancel();
          if (!ready.isCompleted) {
            ready.completeError(Exception('WebSocket closed before handshake'));
          }
        },
        cancelOnError: false,
      );

      timeout = Timer(const Duration(seconds: 8), () {
        if (!ready.isCompleted) {
          ready.completeError(
            Exception(
              'Connection timed out after 8s.\n'
              'Check bridge is running and URL is correct.\n'
              'If on HTTPS page, ws:// is blocked by the browser.',
            ),
          );
        }
      });

      // Nudge server; some stacks need a first frame
      try {
        _channel!.sink.add(jsonEncode({'type': 'ping', 'ts': DateTime.now().millisecondsSinceEpoch}));
      } catch (_) {}

      await ready.future;
      timeout.cancel();
      _startHeartbeat();
      _controller.add(BridgeEvent(type: BridgeEventType.connected));
    } catch (e) {
      _connected = false;
      _controller.add(BridgeEvent(
        type: BridgeEventType.error,
        data: {'message': e.toString()},
      ));
      rethrow;
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
      send({'type': 'ping', 'ts': DateTime.now().millisecondsSinceEpoch});
    });
  }

  Future<void> disconnect() async {
    _heartbeat?.cancel();
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _connected = false;
  }

  void send(Map<String, dynamic> payload) {
    if (_channel == null || !_connected) return;
    try {
      _channel!.sink.add(jsonEncode(payload));
    } catch (e) {
      debugPrint('send failed: $e');
    }
  }

  void createSession({String? name, String? workDir, String? model}) {
    send({
      'type': 'session.create',
      'name': name,
      'workDir': workDir,
      'model': model,
    });
  }

  void sendPrompt(String sessionId, String prompt, {List<String>? attachments}) {
    send({
      'type': 'prompt',
      'sessionId': sessionId,
      'content': prompt,
      'attachments': attachments ?? [],
    });
  }

  void interrupt(String sessionId) {
    send({'type': 'interrupt', 'sessionId': sessionId});
  }

  void inject(String sessionId, String text) {
    send({'type': 'inject', 'sessionId': sessionId, 'content': text});
  }

  void setYolo(String sessionId, bool enabled) {
    send({'type': 'config', 'sessionId': sessionId, 'yolo': enabled});
  }

  void setPlanMode(String sessionId, bool enabled) {
    send({'type': 'config', 'sessionId': sessionId, 'planMode': enabled});
  }

  void setModel(String sessionId, String model) {
    send({'type': 'config', 'sessionId': sessionId, 'model': model});
  }

  void approveTool(String sessionId, String toolCallId, {bool always = false}) {
    send({
      'type': 'tool.approve',
      'sessionId': sessionId,
      'toolCallId': toolCallId,
      'always': always,
    });
  }

  void denyTool(String sessionId, String toolCallId) {
    send({
      'type': 'tool.deny',
      'sessionId': sessionId,
      'toolCallId': toolCallId,
    });
  }

  void listSessions() {
    send({'type': 'session.list'});
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}

enum BridgeEventType {
  connected,
  disconnected,
  error,
  pong,
  sessionCreated,
  sessionList,
  thinkingDelta,
  contentDelta,
  toolCall,
  toolOutput,
  toolStatus,
  turnComplete,
  approvalRequired,
  status,
  unknown,
}

class BridgeEvent {
  final BridgeEventType type;
  final Map<String, dynamic> data;

  BridgeEvent({required this.type, this.data = const {}});

  factory BridgeEvent.fromJson(Map<String, dynamic> j) {
    final t = j['type'] as String? ?? '';
    final type = switch (t) {
      'connected' => BridgeEventType.connected,
      'disconnected' => BridgeEventType.disconnected,
      'error' => BridgeEventType.error,
      'pong' => BridgeEventType.pong,
      'session.created' => BridgeEventType.sessionCreated,
      'session.list' => BridgeEventType.sessionList,
      'thinking.delta' => BridgeEventType.thinkingDelta,
      'content.delta' => BridgeEventType.contentDelta,
      'tool.call' => BridgeEventType.toolCall,
      'tool.output' => BridgeEventType.toolOutput,
      'tool.status' => BridgeEventType.toolStatus,
      'turn.complete' => BridgeEventType.turnComplete,
      'approval.required' => BridgeEventType.approvalRequired,
      'status' => BridgeEventType.status,
      _ => BridgeEventType.unknown,
    };
    return BridgeEvent(type: type, data: j);
  }
}
