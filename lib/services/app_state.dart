import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/session.dart';
import '../models/message.dart';
import 'bridge_service.dart';
import 'openai_stream.dart';

enum ChatBackend { direct, bridge }

class AppState extends ChangeNotifier {
  final BridgeService bridge = BridgeService();
  late OpenAIStreamService direct;

  final List<KimiSession> sessions = [];
  KimiSession? activeSession;
  final Map<String, List<ChatMessage>> messages = {};

  String? bridgeUrl;
  bool connecting = false;
  String? connectionError;
  double? latencyMs;
  StreamSubscription? _sub;

  ChatBackend backend = ChatBackend.bridge;
  String selectedModel = 'gpt-4.1-nano';
  bool swarmMode = false;
  final List<String> swarmModels = ['gpt-4.1-nano', 'gpt-4.1-mini', 'gpt-4o-mini'];
  bool isGenerating = false;
  StreamSubscription? _genSub;

  String directBaseUrl = ProviderPresets.chatAnywhere.baseUrl;
  String directApiKey = ProviderPresets.chatAnywhere.apiKey;

  Future<void> init() async {
    bridgeUrl = 'ws://85.121.148.62:9876';
    direct = OpenAIStreamService(baseUrl: directBaseUrl, apiKey: directApiKey);
    _sub = bridge.events.listen(_onBridgeEvent);
    _ensureLocalSession();
    if (!BridgeService.isMixedContentBlocked(bridgeUrl!)) {
      unawaited(connect());
    }
  }

  void _ensureLocalSession() {
    if (sessions.isEmpty) {
      final s = KimiSession(id: const Uuid().v4(), name: 'Chat', model: selectedModel, yolo: true);
      sessions.add(s);
      activeSession = s;
      messages[s.id] = [];
    }
  }

  void setBackend(ChatBackend b) { backend = b; notifyListeners(); }
  void setModel(String m) {
    selectedModel = m;
    activeSession = activeSession?.copyWith(model: m);
    notifyListeners();
  }
  void setSwarm(bool v) { swarmMode = v; notifyListeners(); }
  void updateDirectProvider({String? baseUrl, String? apiKey}) {
    if (baseUrl != null) directBaseUrl = baseUrl;
    if (apiKey != null) directApiKey = apiKey;
    direct = OpenAIStreamService(baseUrl: directBaseUrl, apiKey: directApiKey);
    notifyListeners();
  }

  Future<void> connect() async {
    if (bridgeUrl == null || bridgeUrl!.isEmpty) return;
    connecting = true; connectionError = null; notifyListeners();
    try {
      await bridge.connect(bridgeUrl!);
      if (bridge.isConnected) bridge.listSessions();
    } catch (e) {
      connectionError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      connecting = false; notifyListeners();
    }
  }

  void disconnect() { bridge.disconnect(); notifyListeners(); }

  void createSession({String? name}) {
    final s = KimiSession(
      id: const Uuid().v4(),
      name: name ?? 'Chat ${sessions.length + 1}',
      model: selectedModel,
      yolo: true,
    );
    sessions.insert(0, s);
    activeSession = s;
    messages[s.id] = [];
    notifyListeners();
    if (backend == ChatBackend.bridge && bridge.isConnected) {
      bridge.createSession(name: s.name, model: selectedModel);
    }
  }

  void selectSession(KimiSession s) { activeSession = s; notifyListeners(); }

  void deleteSession(String id) {
    sessions.removeWhere((s) => s.id == id);
    messages.remove(id);
    if (activeSession?.id == id) activeSession = sessions.isNotEmpty ? sessions.first : null;
    if (activeSession == null) _ensureLocalSession();
    notifyListeners();
  }

  List<ChatMessage> messagesFor(String sessionId) => messages[sessionId] ?? [];

  Future<void> sendPrompt(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isGenerating) return;
    if (activeSession == null) createSession();
    final s = activeSession!;
    final sid = s.id;

    messages.putIfAbsent(sid, () => []).add(ChatMessage(role: MessageRole.user, content: trimmed));
    messages[sid]!.add(ChatMessage(role: MessageRole.assistant, isStreaming: true));
    s.status = SessionStatus.streaming;
    s.messageCount += 1;
    isGenerating = true;
    notifyListeners();

    if (backend == ChatBackend.bridge && bridge.isConnected) {
      bridge.sendPrompt(sid, trimmed);
      return;
    }
    await _runDirect(sid, trimmed);
  }

  Future<void> _runDirect(String sessionId, String userText) async {
    final history = <Map<String, String>>[];
    for (final m in messages[sessionId] ?? []) {
      if (m.role == MessageRole.user) history.add({'role': 'user', 'content': m.content});
      else if (m.role == MessageRole.assistant && m.content.isNotEmpty) {
        history.add({'role': 'assistant', 'content': m.content});
      }
    }
    if (history.isEmpty || history.last['role'] != 'user') {
      history.add({'role': 'user', 'content': userText});
    }

    final stream = swarmMode
        ? direct.swarm(models: List.from(swarmModels), messages: history)
        : direct.chat(model: selectedModel, messages: history);

    _genSub?.cancel();
    _genSub = stream.listen((ev) {
      final type = ev['type'];
      if (type == 'content') _appendContent(sessionId, ev['text'] ?? '');
      else if (type == 'thinking') _appendThinking(sessionId, ev['text'] ?? '');
      else if (type == 'status') _appendContent(sessionId, '\n_${ev['text']}_\n');
      else if (type == 'error') { _appendContent(sessionId, '\n⚠️ ${ev['text']}\n'); _finishTurn(sessionId); }
      else if (type == 'done') {
        if (ev['model'] != null) activeSession = activeSession?.copyWith(model: ev['model']);
        _finishTurn(sessionId);
      }
    }, onError: (e) { _appendContent(sessionId, '\n⚠️ $e\n'); _finishTurn(sessionId); },
       onDone: () => _finishTurn(sessionId));
  }

  void interrupt() {
    _genSub?.cancel(); _genSub = null;
    final s = activeSession;
    if (s != null) {
      if (backend == ChatBackend.bridge && bridge.isConnected) bridge.interrupt(s.id);
      _finishTurn(s.id);
    }
  }

  void toggleYolo() {
    final s = activeSession; if (s == null) return;
    s.yolo = !s.yolo;
    if (bridge.isConnected) bridge.setYolo(s.id, s.yolo);
    notifyListeners();
  }

  void togglePlanMode() {
    final s = activeSession; if (s == null) return;
    s.planMode = !s.planMode;
    if (bridge.isConnected) bridge.setPlanMode(s.id, s.planMode);
    notifyListeners();
  }

  void approveTool(String toolCallId, {bool always = false}) {
    final s = activeSession; if (s == null) return;
    if (bridge.isConnected) bridge.approveTool(s.id, toolCallId, always: always);
  }

  void denyTool(String toolCallId) {
    final s = activeSession; if (s == null) return;
    if (bridge.isConnected) bridge.denyTool(s.id, toolCallId);
  }

  void _onBridgeEvent(BridgeEvent e) {
    switch (e.type) {
      case BridgeEventType.connected:
        connectionError = null; notifyListeners(); break;
      case BridgeEventType.disconnected:
      case BridgeEventType.error:
        connectionError = e.data['message'] as String?; notifyListeners(); break;
      case BridgeEventType.thinkingDelta:
        _appendThinking(e.data['sessionId'] as String? ?? activeSession?.id ?? '', e.data['delta'] as String? ?? ''); break;
      case BridgeEventType.contentDelta:
        _appendContent(e.data['sessionId'] as String? ?? activeSession?.id ?? '', e.data['delta'] as String? ?? ''); break;
      case BridgeEventType.turnComplete:
        _finishTurn(e.data['sessionId'] as String? ?? activeSession?.id ?? ''); break;
      case BridgeEventType.pong:
        final sent = e.data['ts'] as int?;
        if (sent != null) { latencyMs = (DateTime.now().millisecondsSinceEpoch - sent).toDouble(); notifyListeners(); }
        break;
      default: break;
    }
  }

  void _appendThinking(String sessionId, String delta) {
    if (sessionId.isEmpty) return;
    final msgs = messages[sessionId];
    if (msgs == null || msgs.isEmpty) return;
    final last = msgs.last;
    if (last.role != MessageRole.assistant) return;
    msgs[msgs.length - 1] = last.copyWith(reasoningContent: (last.reasoningContent ?? '') + delta);
    final s = sessions.cast<KimiSession?>().firstWhere((x) => x?.id == sessionId, orElse: () => null);
    if (s != null) s.status = SessionStatus.thinking;
    notifyListeners();
  }

  void _appendContent(String sessionId, String delta) {
    if (sessionId.isEmpty) return;
    final msgs = messages[sessionId];
    if (msgs == null || msgs.isEmpty) return;
    final last = msgs.last;
    if (last.role != MessageRole.assistant) return;
    msgs[msgs.length - 1] = last.copyWith(content: last.content + delta);
    final s = sessions.cast<KimiSession?>().firstWhere((x) => x?.id == sessionId, orElse: () => null);
    if (s != null) s.status = SessionStatus.streaming;
    notifyListeners();
  }

  void _finishTurn(String sessionId) {
    isGenerating = false;
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
    _sub?.cancel(); _genSub?.cancel(); bridge.dispose(); super.dispose();
  }
}
