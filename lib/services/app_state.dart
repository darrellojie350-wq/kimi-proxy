import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/session.dart';
import 'bridge_service.dart';

/// Central state for Kimi Proxy — a ChangeNotifier that bridges WebSocket
/// events to the UI model and persists settings.
class AppState extends ChangeNotifier {
  final BridgeService bridge = BridgeService();
  final List<Session> sessions = [];
  Session? activeSession;
  StreamSubscription? _sub;
  SharedPreferences? _prefs;
  bool _initialized = false;

  // Secure quick-tunnel endpoint for the current Kimi CLI bridge deployment.
  // Users can replace it from Settings with a permanent VPS URL.
  String _bridgeUrl = 'wss://blast-sought-safe-pixel.trycloudflare.com';
  String get bridgeUrl => _bridgeUrl;
  String _theme = 'dark';
  String get theme => _theme;
  String _fontSize = 'medium';
  String get fontSize => _fontSize;
  final String _defaultModel = 'kimi';
  String get defaultModel => _defaultModel;

  String get connectionStatus => bridge.isConnected ? 'online' : 'offline';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _prefs = await SharedPreferences.getInstance();
    _bridgeUrl = _prefs!.getString('bridgeUrl') ?? _bridgeUrl;
    _theme = _prefs!.getString('theme') ?? 'dark';
    _fontSize = _prefs!.getString('fontSize') ?? 'medium';

    _sub = bridge.events.listen(_onBridgeEvent);
    _ensureLocalSession();
    notifyListeners();
    // Make the preview/app usable on first launch. The endpoint remains
    // editable in Settings for a permanent VPS or named tunnel.
    unawaited(connect());
  }

  void setBridgeUrl(String url) {
    _bridgeUrl = url;
    _prefs?.setString('bridgeUrl', url);
    notifyListeners();
  }

  void setTheme(String t) {
    _theme = t;
    _prefs?.setString('theme', t);
    notifyListeners();
  }

  /// Connect to the bridge. Call after settings are configured.
  Future<void> connect() async {
    if (_bridgeUrl.isEmpty) return;
    await bridge.connect(_bridgeUrl);
  }

  void disconnect() => bridge.disconnect();

  Session createSession({String? name, String? model}) {
    final id = const Uuid().v4();
    final s = Session(id: id, name: name, model: model ?? _defaultModel);
    sessions.add(s);
    selectSession(s);
    // If online, bridge will echo and adopt
    if (bridge.isConnected) {
      bridge.createSession(name: name, model: model);
    }
    return s;
  }

  void selectSession(Session s) {
    activeSession = s;
    notifyListeners();
  }

  void selectSessionById(String id) {
    final s = sessions.where((x) => x.id == id || x.serverId == id).firstOrNull;
    if (s != null) selectSession(s);
  }

  void deleteSession(String sessionId) {
    sessions.removeWhere((s) => s.id == sessionId || s.serverId == sessionId);
    if (activeSession != null &&
        (activeSession!.id == sessionId || activeSession!.serverId == sessionId)) {
      activeSession = sessions.isNotEmpty ? sessions.last : null;
    }
    if (bridge.isConnected) bridge.deleteSession(sessionId);
    notifyListeners();
  }

  void sendPrompt(String text) {
    if (activeSession == null) return;
    final msg = Message(
      id: const Uuid().v4(),
      role: 'user',
      content: text,
    );
    activeSession!.messages.add(msg);
    activeSession!.status = 'streaming';
    // Create placeholder assistant message
    final assistant = Message(id: const Uuid().v4(), role: 'assistant', streaming: true);
    activeSession!.messages.add(assistant);
    notifyListeners();
    if (bridge.isConnected) {
      bridge.sendPrompt(activeSession!.serverId ?? activeSession!.id, text);
    }
  }

  void interrupt() {
    if (activeSession == null) return;
    bridge.interrupt(activeSession!.serverId ?? activeSession!.id);
  }

  void config({bool? yolo, bool? planMode, String? model}) {
    if (activeSession == null) return;
    if (yolo != null) activeSession!.yolo = yolo;
    if (planMode != null) activeSession!.planMode = planMode;
    if (model != null) activeSession!.model = model;
    if (bridge.isConnected) {
      bridge.config(
        activeSession!.serverId ?? activeSession!.id,
        yolo: yolo,
        planMode: planMode,
        model: model,
      );
    }
    notifyListeners();
  }

  // ---- Bridge event handling -----------------------------------------------
  void _onBridgeEvent(BridgeEvent ev) {
    final d = ev.data;
    switch (ev.type) {
      case 'session.list':
        final list = d['sessions'] as List?;
        if (list != null) {
          for (final j in list) {
            _adoptOrUpdate(j as Map<String, dynamic>);
          }
          notifyListeners();
        }
        break;
      case 'session.created':
        _adoptOrUpdate(d['session'] as Map<String, dynamic>? ?? {});
        notifyListeners();
        break;
      case 'session.deleted':
        final sid = d['sessionId'] as String?;
        if (sid != null) {
          sessions.removeWhere((s) => s.id == sid || s.serverId == sid);
          if (activeSession != null &&
              (activeSession!.id == sid || activeSession!.serverId == sid)) {
            activeSession = sessions.isNotEmpty ? sessions.last : null;
          }
          notifyListeners();
        }
        break;
      case 'session.renamed':
        _updateSessionFromServer(d['session'] as Map<String, dynamic>? ?? {});
        notifyListeners();
        break;
      case 'status':
        final sid = d['sessionId'] as String?;
        final s = _findSession(sid);
        if (s != null) {
          s.status = d['status'] as String? ?? s.status;
          if (d['session'] is Map) _updateSessionFromServer(d['session'] as Map<String, dynamic>);
          notifyListeners();
        }
        break;
      case 'content.delta':
        _handleDelta(d, 'content');
        break;
      case 'thinking.delta':
        _handleDelta(d, 'thinking');
        break;
      case 'tool.call':
        _handleToolCall(d);
        break;
      case 'tool.output':
        _handleToolOutput(d);
        break;
      case 'tool.status':
        _handleToolStatus(d);
        break;
      case 'turn.complete':
        final sid = d['sessionId'] as String?;
        final s = _findSession(sid);
        if (s != null) {
          s.status = 'idle';
          // Finalize the streaming assistant message
          for (final m in s.messages.reversed) {
            if (m.streaming) {
              m.streaming = false;
              break;
            }
          }
          s.messageCount++;
          s.updatedAt = DateTime.now();
          notifyListeners();
        }
        break;
      case 'error':
        final sid = d['sessionId'] as String?;
        final s = _findSession(sid);
        if (s != null) s.status = 'error';
        notifyListeners();
        break;
      case 'connection.change':
        if (d['status'] == 'online' && bridge.isConnected) {
          bridge.listSessions();
        }
        notifyListeners();
        break;
    }
  }

  void _handleDelta(Map<String, dynamic> d, String field) {
    final sid = d['sessionId'] as String?;
    final delta = d['delta'] as String?;
    final s = _findSession(sid);
    if (s == null || delta == null || delta.isEmpty) return;
    if (s.messages.isEmpty) {
      final msg = Message(id: const Uuid().v4(), role: 'assistant', streaming: true);
      s.messages.add(msg);
    }
    final last = s.messages.last;
    if (field == 'thinking') {
      last.thinking = (last.thinking ?? '') + delta;
    } else {
      last.content += delta;
    }
    s.status = field == 'thinking' ? 'thinking' : 'streaming';
    notifyListeners();
  }

  void _handleToolCall(Map<String, dynamic> d) {
    final sid = d['sessionId'] as String?;
    final s = _findSession(sid);
    if (s == null) return;
    final entry = ToolEntry(
      id: d['toolCallId'] as String? ?? const Uuid().v4(),
      name: d['name'] as String? ?? 'tool',
      arguments: (d['arguments'] as Map?)?.cast<String, dynamic>() ?? {},
      status: 'running',
      startedAt: DateTime.now().millisecondsSinceEpoch,
    );
    s.tools.add(entry);
    s.status = 'toolRunning';
    notifyListeners();
  }

  void _handleToolOutput(Map<String, dynamic> d) {
    final sid = d['sessionId'] as String?;
    final s = _findSession(sid);
    if (s == null) return;
    final tid = d['toolCallId'] as String?;
    final output = d['output'] as String?;
    for (final t in s.tools) {
      if (t.id == tid) {
        t.output = output;
        break;
      }
    }
    notifyListeners();
  }

  void _handleToolStatus(Map<String, dynamic> d) {
    final sid = d['sessionId'] as String?;
    final s = _findSession(sid);
    if (s == null) return;
    final tid = d['toolCallId'] as String?;
    final status = d['status'] as String? ?? 'success';
    for (final t in s.tools) {
      if (t.id == tid) {
        t.status = status;
        t.durationMs = d['durationMs'] as int?;
        break;
      }
    }
    notifyListeners();
  }

  Session? _findSession(String? id) {
    if (id == null) return null;
    for (final s in sessions) {
      if (s.id == id || s.serverId == id) return s;
    }
    return null;
  }

  void _adoptOrUpdate(Map<String, dynamic> j) {
    final serverId = j['id'] as String?;
    if (serverId == null) return;
    // Try to match by serverId (local session awaiting echo)
    for (final s in sessions) {
      if (s.serverId == serverId) {
        _updateSessionFromJson(s, j);
        return;
      }
    }
    // Match by name + no serverId (pending local)
    for (final s in sessions) {
      final name = j['name'] as String?;
      if (s.serverId == null && name != null && s.name == name) {
        s.serverId = serverId;
        _updateSessionFromJson(s, j);
        return;
      }
    }
    // New session from server
    final ns = Session(
      id: serverId,
      serverId: serverId,
      name: j['name'] as String?,
      status: j['status'] as String? ?? 'idle',
      model: j['model'] as String?,
      yolo: j['yolo'] as bool? ?? true,
      planMode: j['planMode'] as bool? ?? false,
      createdAt: _parseDate(j['createdAt']),
      updatedAt: _parseDate(j['updatedAt']),
      messageCount: j['messageCount'] as int? ?? 0,
    );
    sessions.add(ns);
  }

  void _updateSessionFromJson(Session s, Map<String, dynamic> j) {
    s.name = j['name'] as String? ?? s.name;
    s.status = j['status'] as String? ?? s.status;
    s.model = j['model'] as String? ?? s.model;
    s.yolo = j['yolo'] as bool? ?? s.yolo;
    s.planMode = j['planMode'] as bool? ?? s.planMode;
    s.messageCount = j['messageCount'] as int? ?? s.messageCount;
    s.updatedAt = _parseDate(j['updatedAt']) ?? s.updatedAt;
  }

  void _updateSessionFromServer(Map<String, dynamic> j) {
    final sid = j['id'] as String?;
    if (sid == null) return;
    final s = _findSession(sid);
    if (s != null) _updateSessionFromJson(s, j);
  }

  void _ensureLocalSession() {
    if (sessions.isEmpty) {
      createSession();
    } else if (activeSession == null) {
      selectSession(sessions.first);
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    bridge.dispose();
    super.dispose();
  }
}