import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../models/message.dart';
import 'bridge_service.dart';

class AppState extends ChangeNotifier {
  final BridgeService bridge = BridgeService();
  final List<KimiSession> sessions = [];
  KimiSession? activeSession;
  final Map<String, List<ChatMessage>> messages = {};
  String? bridgeUrl;
  bool connecting = false;
  String? connectionError;
  double? latencyMs;
  StreamSubscription? _sub;

  Future<void> init() async {
    // Default bridge URL — user can change in settings
    bridgeUrl = 'ws://85.121.148.62:9876';
    _sub = bridge.events.listen(_onBridgeEvent);
  }

  Future<void> connect() async {
    if (bridgeUrl == null || bridgeUrl!.isEmpty) return;
    connecting = true;
    connectionError = null;
    notifyListeners();
    try {
      await bridge.connect(bridgeUrl!);
      if (bridge.isConnected) {
        bridge.listSessions();
      }
    } catch (e) {
      connectionError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  void disconnect() {
    bridge.disconnect();
    notifyListeners();
  }

  void _onBridgeEvent(BridgeEvent e) {
    switch (e.type) {
      case BridgeEventType.connected:
        connectionError = null;
        notifyListeners();
        break;
      case BridgeEventType.disconnected:
      case BridgeEventType.error:
        connectionError = e.data['message'] as String?;
        notifyListeners();
        break;
      case BridgeEventType.sessionCreated:
        final s = KimiSession.fromJson(e.data['session'] as Map<String, dynamic>);
        sessions.insert(0, s);
        activeSession = s;
        messages[s.id] = [];
        notifyListeners();
        break;
      case BridgeEventType.sessionList:
        final list = (e.data['sessions'] as List?) ?? [];
        sessions.clear();
        for (final item in list) {
          sessions.add(KimiSession.fromJson(item as Map<String, dynamic>));
        }
        if (sessions.isNotEmpty && activeSession == null) {
          activeSession = sessions.first;
        }
        notifyListeners();
        break;
      case BridgeEventType.thinkingDelta:
        _appendThinking(e.data['sessionId'] as String, e.data['delta'] as String? ?? '');
        break;
      case BridgeEventType.contentDelta:
        _appendContent(e.data['sessionId'] as String, e.data['delta'] as String? ?? '');
        break;
      case BridgeEventType.toolCall:
        _addToolCall(e.data);
        break;
      case BridgeEventType.toolOutput:
        _updateToolOutput(e.data);
        break;
      case BridgeEventType.toolStatus:
        _updateToolStatus(e.data);
        break;
      case BridgeEventType.turnComplete:
        _finishTurn(e.data['sessionId'] as String);
        break;
      case BridgeEventType.approvalRequired:
        // tool status already pending
        notifyListeners();
        break;
      case BridgeEventType.pong:
        final sent = e.data['ts'] as int?;
        if (sent != null) {
          latencyMs = (DateTime.now().millisecondsSinceEpoch - sent).toDouble();
          notifyListeners();
        }
        break;
      default:
        break;
    }
  }

  List<ChatMessage> messagesFor(String sessionId) => messages[sessionId] ?? [];

  void selectSession(KimiSession s) {
    activeSession = s;
    notifyListeners();
  }

  void createSession({String? name}) {
    bridge.createSession(name: name);
  }

  void sendPrompt(String text) {
    final s = activeSession;
    if (s == null || text.trim().isEmpty) return;

    final userMsg = ChatMessage(role: MessageRole.user, content: text.trim());
    messages.putIfAbsent(s.id, () => []).add(userMsg);

    final assistantMsg = ChatMessage(
      role: MessageRole.assistant,
      isStreaming: true,
    );
    messages[s.id]!.add(assistantMsg);

    s.status = SessionStatus.streaming;
    s.messageCount += 1;
    notifyListeners();

    bridge.sendPrompt(s.id, text.trim());
  }

  void interrupt() {
    final s = activeSession;
    if (s == null) return;
    bridge.interrupt(s.id);
    s.status = SessionStatus.idle;
    final msgs = messages[s.id];
    if (msgs != null && msgs.isNotEmpty && msgs.last.isStreaming) {
      msgs[msgs.length - 1] = msgs.last.copyWith(isStreaming: false);
    }
    notifyListeners();
  }

  void toggleYolo() {
    final s = activeSession;
    if (s == null) return;
    s.yolo = !s.yolo;
    bridge.setYolo(s.id, s.yolo);
    notifyListeners();
  }

  void togglePlanMode() {
    final s = activeSession;
    if (s == null) return;
    s.planMode = !s.planMode;
    bridge.setPlanMode(s.id, s.planMode);
    notifyListeners();
  }

  void approveTool(String toolCallId, {bool always = false}) {
    final s = activeSession;
    if (s == null) return;
    bridge.approveTool(s.id, toolCallId, always: always);
  }

  void denyTool(String toolCallId) {
    final s = activeSession;
    if (s == null) return;
    bridge.denyTool(s.id, toolCallId);
  }

  // --- internal stream helpers ---

  void _appendThinking(String sessionId, String delta) {
    final msgs = messages[sessionId];
    if (msgs == null || msgs.isEmpty) return;
    final last = msgs.last;
    if (last.role != MessageRole.assistant) return;
    final current = last.reasoningContent ?? '';
    msgs[msgs.length - 1] = last.copyWith(reasoningContent: current + delta);
    final s = sessions.cast<KimiSession?>().firstWhere((x) => x?.id == sessionId, orElse: () => null);
    if (s != null) s.status = SessionStatus.thinking;
    notifyListeners();
  }

  void _appendContent(String sessionId, String delta) {
    final msgs = messages[sessionId];
    if (msgs == null || msgs.isEmpty) return;
    final last = msgs.last;
    if (last.role != MessageRole.assistant) return;
    msgs[msgs.length - 1] = last.copyWith(content: last.content + delta);
    final s = sessions.cast<KimiSession?>().firstWhere((x) => x?.id == sessionId, orElse: () => null);
    if (s != null) s.status = SessionStatus.streaming;
    notifyListeners();
  }

  void _addToolCall(Map<String, dynamic> data) {
    final sessionId = data['sessionId'] as String;
    final msgs = messages[sessionId];
    if (msgs == null || msgs.isEmpty) return;
    final last = msgs.last;
    if (last.role != MessageRole.assistant) return;

    final tc = ToolCall(
      id: data['toolCallId'] as String? ?? '',
      name: data['name'] as String? ?? 'tool',
      arguments: Map<String, dynamic>.from(data['arguments'] as Map? ?? {}),
      status: ToolStatus.running,
      startedAt: DateTime.now(),
    );
    final updated = List<ToolCall>.from(last.toolCalls)..add(tc);
    msgs[msgs.length - 1] = last.copyWith(toolCalls: updated);

    final s = sessions.cast<KimiSession?>().firstWhere((x) => x?.id == sessionId, orElse: () => null);
    if (s != null) s.status = SessionStatus.toolRunning;
    notifyListeners();
  }

  void _updateToolOutput(Map<String, dynamic> data) {
    final sessionId = data['sessionId'] as String;
    final toolCallId = data['toolCallId'] as String;
    final output = data['output'] as String? ?? '';
    final msgs = messages[sessionId];
    if (msgs == null || msgs.isEmpty) return;
    final last = msgs.last;
    final updated = last.toolCalls.map((t) {
      if (t.id == toolCallId) {
        return t.copyWith(output: (t.output ?? '') + output);
      }
      return t;
    }).toList();
    msgs[msgs.length - 1] = last.copyWith(toolCalls: updated);
    notifyListeners();
  }

  void _updateToolStatus(Map<String, dynamic> data) {
    final sessionId = data['sessionId'] as String;
    final toolCallId = data['toolCallId'] as String;
    final statusStr = data['status'] as String? ?? 'success';
    final status = ToolStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => ToolStatus.success,
    );
    final msgs = messages[sessionId];
    if (msgs == null || msgs.isEmpty) return;
    final last = msgs.last;
    final updated = last.toolCalls.map((t) {
      if (t.id == toolCallId) {
        return t.copyWith(status: status, finishedAt: DateTime.now());
      }
      return t;
    }).toList();
    msgs[msgs.length - 1] = last.copyWith(toolCalls: updated);
    notifyListeners();
  }

  void _finishTurn(String sessionId) {
    final msgs = messages[sessionId];
    if (msgs != null && msgs.isNotEmpty && msgs.last.isStreaming) {
      msgs[msgs.length - 1] = msgs.last.copyWith(isStreaming: false);
    }
    final s = sessions.cast<KimiSession?>().firstWhere((x) => x?.id == sessionId, orElse: () => null);
    if (s != null) s.status = SessionStatus.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    bridge.dispose();
    super.dispose();
  }
}
