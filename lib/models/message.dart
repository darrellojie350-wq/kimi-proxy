import 'package:uuid/uuid.dart';

enum MessageRole { user, assistant, system, tool }

enum ToolStatus { pending, running, success, error, cancelled }

class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  String? output;
  ToolStatus status;
  DateTime? startedAt;
  DateTime? finishedAt;

  ToolCall({
    required this.id,
    required this.name,
    this.arguments = const {},
    this.output,
    this.status = ToolStatus.pending,
    this.startedAt,
    this.finishedAt,
  });

  ToolCall copyWith({
    String? output,
    ToolStatus? status,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return ToolCall(
      id: id,
      name: name,
      arguments: arguments,
      output: output ?? this.output,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }
}

class ChatMessage {
  final String id;
  final MessageRole role;
  String content;
  String? reasoningContent;
  List<ToolCall> toolCalls;
  DateTime createdAt;
  bool isStreaming;
  int? inputTokens;
  int? outputTokens;
  int? thinkingTokens;

  ChatMessage({
    String? id,
    required this.role,
    this.content = '',
    this.reasoningContent,
    List<ToolCall>? toolCalls,
    DateTime? createdAt,
    this.isStreaming = false,
    this.inputTokens,
    this.outputTokens,
    this.thinkingTokens,
  })  : id = id ?? const Uuid().v4(),
        toolCalls = toolCalls ?? [],
        createdAt = createdAt ?? DateTime.now();

  ChatMessage copyWith({
    String? content,
    String? reasoningContent,
    List<ToolCall>? toolCalls,
    bool? isStreaming,
    int? inputTokens,
    int? outputTokens,
    int? thinkingTokens,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      toolCalls: toolCalls ?? this.toolCalls,
      createdAt: createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      thinkingTokens: thinkingTokens ?? this.thinkingTokens,
    );
  }

  bool get hasThinking => reasoningContent != null && reasoningContent!.isNotEmpty;
  bool get hasTools => toolCalls.isNotEmpty;
}
