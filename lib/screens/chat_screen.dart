import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/message_bubble.dart';
import '../widgets/thinking_row.dart';
import '../widgets/tool_call_line.dart';

/// Streaming chat list for the active session.
///
/// Renders each message as a [MessageBubble] (followed by a [ThinkingRow]
/// when the message carries reasoning), then the session's tool calls as
/// [ToolCallLine] entries. Auto-scrolls to the bottom as new content arrives,
/// but during streaming only follows while the user is near the bottom so
/// reading history isn't yanked.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _followTolerance = 160.0;

  final ScrollController _controller = ScrollController();
  String? _lastSessionId;
  int _lastItems = 0;
  bool _lastStreaming = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleScroll({
    required String sessionId,
    required int items,
    required bool streaming,
  }) {
    final structural = items != _lastItems || sessionId != _lastSessionId;
    final streamingChanged = streaming != _lastStreaming;
    _lastSessionId = sessionId;
    _lastItems = items;
    _lastStreaming = streaming;
    if (!structural && !streamingChanged) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followBottom(structural: structural);
    });
  }

  void _followBottom({required bool structural}) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.maxScrollExtent <= 0) return;
    if (!structural &&
        position.maxScrollExtent - position.pixels > _followTolerance) {
      // User is reading history — don't yank them down mid-stream.
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(position.maxScrollExtent);
    } else {
      _controller.animateTo(
        position.maxScrollExtent,
        duration: Tokens.durBase,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.activeSession;
    if (session == null || session.messages.isEmpty) {
      return const SizedBox.shrink();
    }

    final messages = session.messages;
    final streaming = (messages.isNotEmpty && messages.last.streaming) ||
        session.status == 'streaming' ||
        session.status == 'thinking' ||
        session.status == 'toolRunning';

    final items = <Widget>[];
    for (final message in messages) {
      items.add(MessageBubble(message: message));
      if (message.thinking != null && message.thinking!.isNotEmpty) {
        items.add(ThinkingRow(message: message));
      }
    }
    for (final tool in session.tools) {
      items.add(ToolCallLine(tool: tool));
    }

    _scheduleScroll(
      sessionId: session.id,
      items: items.length,
      streaming: streaming,
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Tokens.contentMaxWidth),
        child: ListView.builder(
          controller: _controller,
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.sp4,
            vertical: Tokens.sp4,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => items[index],
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        ),
      ),
    );
  }
}
