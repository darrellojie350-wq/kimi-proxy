import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

/// WebSocket bridge to VPS Kimi Code CLI sessions.
/// Protocol is intentionally simple and stream-first.
class BridgeService {
  WebSocketChannel? _channel;
  final _controller = StreamController<BridgeEvent>.broadcast();
  String? _vpsUrl;
  bool _connected = false;
  Timer? _heartbeat;

  Stream<BridgeEvent> get events => _controller.stream;
  bool get isConnected => _connected;

  Future<void> connect(String url) async {
    await disconnect();
    _vpsUrl = url;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _connected = true;
      _controller.add(BridgeEvent(type: BridgeEventType.connected));
      _startHeartbeat();

      _channel!.stream.listen(
        (data) {
          try {
            final map = jsonDecode(data as String) as Map<String, dynamic>;
            _controller.add(BridgeEvent.fromJson(map));
          } catch (e) {
            debugPrint('Bridge parse error: $e');
          }
        },
        onError: (e) {
          _connected = false;
          _controller.add(BridgeEvent(type: BridgeEventType.error, data: {'message': e.toString()}));
        },
        onDone: () {
          _connected = false;
          _controller.add(BridgeEvent(type: BridgeEventType.disconnected));
          _heartbeat?.cancel();
        },
      );
    } catch (e) {
      _connected = false;
      _controller.add(BridgeEvent(type: BridgeEventType.error, data: {'message': e.toString()}));
      rethrow;
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
      send({'type': 'ping'});
    });
  }

  Future<void> disconnect() async {
    _heartbeat?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _connected = false;
  }

  void send(Map<String, dynamic> payload) {
    if (_channel == null || !_connected) return;
    _channel!.sink.add(jsonEncode(payload));
  }

  // High-level commands
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
