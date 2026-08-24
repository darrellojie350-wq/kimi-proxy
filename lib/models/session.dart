import 'dart:convert';

class Session {
  final String id;
  String name;
  String? serverId;
  String? workDir;
  String? model;
  String status; // idle, streaming, thinking, toolRunning, error
  bool yolo;
  bool planMode;
  bool thinkingEnabled;
  DateTime createdAt;
  DateTime updatedAt;
  int messageCount;
  bool pinned;
  List<Message> messages;
  List<ToolEntry> tools;
  String? kimiSessionId;

  Session({
    required this.id,
    String? name,
    this.serverId,
    this.workDir,
    this.model,
    this.status = 'idle',
    this.yolo = true,
    this.planMode = false,
    this.thinkingEnabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.messageCount = 0,
    this.pinned = false,
    List<Message>? messages,
    List<ToolEntry>? tools,
    this.kimiSessionId,
  })  : name = name ?? 'Session ${id.length > 6 ? id.substring(0, 6) : id}',
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [],
        tools = tools ?? [];

  Message? get lastMessage => messages.isEmpty ? null : messages.last;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'serverId': serverId,
        'workDir': workDir,
        'model': model,
        'status': status,
        'yolo': yolo,
        'planMode': planMode,
        'thinkingEnabled': thinkingEnabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messageCount': messageCount,
        'pinned': pinned,
        'kimiSessionId': kimiSessionId,
        'messages': messages.map((m) => m.toJson()).toList(),
        'tools': tools.map((t) => t.toJson()).toList(),
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        id: j['id'] as String,
        name: j['name'] as String?,
        serverId: j['serverId'] as String?,
        workDir: j['workDir'] as String?,
        model: j['model'] as String?,
        status: j['status'] as String? ?? 'idle',
        yolo: j['yolo'] as bool? ?? true,
        planMode: j['planMode'] as bool? ?? false,
        thinkingEnabled: j['thinkingEnabled'] as bool? ?? true,
        createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt'] as String) : null,
        updatedAt: j['updatedAt'] != null ? DateTime.parse(j['updatedAt'] as String) : null,
        messageCount: j['messageCount'] as int? ?? 0,
        pinned: j['pinned'] as bool? ?? false,
        kimiSessionId: j['kimiSessionId'] as String?,
        messages: (j['messages'] as List?)?.map((m) => Message.fromJson(m as Map<String, dynamic>)).toList(),
        tools: (j['tools'] as List?)?.map((t) => ToolEntry.fromJson(t as Map<String, dynamic>)).toList(),
      );
}

class Message {
  final String id;
  final String role; // user, assistant, system
  String content;
  String? thinking;
  bool streaming;
  DateTime ts;

  Message({
    required this.id,
    required this.role,
    this.content = '',
    this.thinking,
    this.streaming = false,
    DateTime? ts,
  }) : ts = ts ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'thinking': thinking,
        'streaming': streaming,
        'ts': ts.toIso8601String(),
      };

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        role: j['role'] as String? ?? 'assistant',
        content: j['content'] as String? ?? '',
        thinking: j['thinking'] as String?,
        streaming: j['streaming'] as bool? ?? false,
        ts: j['ts'] != null ? DateTime.tryParse(j['ts'] as String) : null,
      );
}

class ToolEntry {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  String status; // pending, running, success, failed
  String? output;
  int? startedAt;
  int? durationMs;

  ToolEntry({
    required this.id,
    required this.name,
    required this.arguments,
    this.status = 'pending',
    this.output,
    this.startedAt,
    this.durationMs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'arguments': arguments,
        'status': status,
        'output': output,
        'startedAt': startedAt,
        'durationMs': durationMs,
      };

  factory ToolEntry.fromJson(Map<String, dynamic> j) => ToolEntry(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'tool',
        arguments: (j['arguments'] as Map?)?.cast<String, dynamic>() ?? const {},
        status: j['status'] as String? ?? 'pending',
        output: j['output'] as String?,
        startedAt: j['startedAt'] as int?,
        durationMs: j['durationMs'] as int?,
      );

  String get argsPreview {
    final s = jsonEncode(arguments);
    return s.length > 60 ? '${s.substring(0, 60)}…' : s;
  }
}
