import 'package:uuid/uuid.dart';

enum SessionStatus { idle, streaming, thinking, toolRunning, error, disconnected }

class KimiSession {
  final String id;
  String name;
  String workDir;
  SessionStatus status;
  DateTime createdAt;
  DateTime updatedAt;
  int messageCount;
  bool pinned;
  String? model;
  bool yolo;
  bool planMode;
  bool thinkingEnabled;

  KimiSession({
    String? id,
    this.name = 'New Session',
    this.workDir = '.',
    this.status = SessionStatus.idle,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.messageCount = 0,
    this.pinned = false,
    this.model,
    this.yolo = true,
    this.planMode = false,
    this.thinkingEnabled = true,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  KimiSession copyWith({
    String? name,
    String? workDir,
    SessionStatus? status,
    DateTime? updatedAt,
    int? messageCount,
    bool? pinned,
    String? model,
    bool? yolo,
    bool? planMode,
    bool? thinkingEnabled,
  }) {
    return KimiSession(
      id: id,
      name: name ?? this.name,
      workDir: workDir ?? this.workDir,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      messageCount: messageCount ?? this.messageCount,
      pinned: pinned ?? this.pinned,
      model: model ?? this.model,
      yolo: yolo ?? this.yolo,
      planMode: planMode ?? this.planMode,
      thinkingEnabled: thinkingEnabled ?? this.thinkingEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'workDir': workDir,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messageCount': messageCount,
        'pinned': pinned,
        'model': model,
        'yolo': yolo,
        'planMode': planMode,
        'thinkingEnabled': thinkingEnabled,
      };

  factory KimiSession.fromJson(Map<String, dynamic> j) => KimiSession(
        id: j['id'],
        name: j['name'] ?? 'Session',
        workDir: j['workDir'] ?? '.',
        status: SessionStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => SessionStatus.idle,
        ),
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(j['updatedAt'] ?? '') ?? DateTime.now(),
        messageCount: j['messageCount'] ?? 0,
        pinned: j['pinned'] ?? false,
        model: j['model'],
        yolo: j['yolo'] ?? true,
        planMode: j['planMode'] ?? false,
        thinkingEnabled: j['thinkingEnabled'] ?? true,
      );
}
