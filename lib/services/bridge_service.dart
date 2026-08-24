import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Bridge wire protocol (kimi-proxy bridge v1.5, ARCHITECTURE.md §5).
/// S->C: connected, pong, session.list, session.created, session.deleted,
///       session.renamed, status, content.delta, thinking.delta, tool.call,
///       tool.output, tool.status, turn.complete, error
/// C->S: ping, session.create, session.list, session.delete, session.rename,
///       prompt, interrupt, config
class BridgeEvent {
  final String type;
  final Map<String, dynamic> data;
  const BridgeEvent(this.type, [this.data = const {}]);
}

class BridgeService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _events = StreamController<BridgeEvent>.broadcast();
  Timer? _heartbeat;
  Timer? _reconnectTimer;
  int _backoff = 1000;
  bool _manualClose = false;
  String? _url;
  bool _connected = false;

  Stream<BridgeEvent> get events => _events.stream;
  bool get isConnected => _connected;

  Future<void> connect(String url) async {
    _manualClose = false;
    _url = url;
    await disconnect();
    _setConnected(false);
    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(_onData, onError: _onError, onDone: _onDone);
      // greet
      _send({'type': 'ping', 'ts': DateTime.now().millisecondsSinceEpoch});
      _startHeartbeat();
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    Map<String, dynamic>? msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final t = msg['type'] as String? ?? '';
    if (t == 'connected' || t == 'pong') {
      if (!_connected) {
        _connected = true;
        _backoff = 1000;
        _events.add(BridgeEvent('connection.change', {'status': 'online'}));
      }
    }
    _events.add(BridgeEvent(t, msg));
  }

  void _onError(Object e) {
    _setConnected(false);
    _scheduleReconnect();
  }

  void _onDone() {
    _setConnected(false);
    if (!_manualClose) _scheduleReconnect();
  }

  void _setConnected(bool v) {
    if (_connected == v) return;
    _connected = v;
    _events.add(BridgeEvent('connection.change', {'status': v ? 'online' : 'offline'}));
  }

  void _scheduleReconnect() {
    _heartbeat?.cancel();
    _reconnectTimer?.cancel();
    if (_manualClose || _url == null) return;
    _reconnectTimer = Timer(Duration(milliseconds: _backoff), () {
      _backoff = (_backoff * 2).clamp(1000, 30000);
      if (_url != null && !_manualClose) connect(_url!);
    });
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
      _send({'type': 'ping', 'ts': DateTime.now().millisecondsSinceEpoch});
    });
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (_) {}
  }

  void send(Map<String, dynamic> payload) => _send(payload);

  // ---- Session ops ------------------------------------------------------
  void createSession({String? name, String? model}) =>
      _send({'type': 'session.create', 'name': name, 'model': model});
  void listSessions() => _send({'type': 'session.list'});
  void deleteSession(String sessionId) => _send({'type': 'session.delete', 'sessionId': sessionId});
  void renameSession(String sessionId, String name) =>
      _send({'type': 'session.rename', 'sessionId': sessionId, 'name': name});
  void sendPrompt(String sessionId, String content) =>
      _send({'type': 'prompt', 'sessionId': sessionId, 'content': content});
  void interrupt(String sessionId) => _send({'type': 'interrupt', 'sessionId': sessionId});
  void config(String sessionId, {bool? yolo, bool? planMode, String? model}) =>
      _send({
        'type': 'config',
        'sessionId': sessionId,
        if (yolo != null) 'yolo': yolo,
        if (planMode != null) 'planMode': planMode,
        if (model != null) 'model': model,
      });

  Future<void> disconnect() async {
    _manualClose = true;
    _heartbeat?.cancel();
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _setConnected(false);
  }

  void dispose() {
    _manualClose = true;
    _heartbeat?.cancel();
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _events.close();
  }
}
