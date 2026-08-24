import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/session.dart';
import '../theme/tokens.dart';

/// A single chat message in iOS style:
/// - `user` — right-aligned pill, system gray fill, 18pt radius.
/// - `assistant` — full-width markdown with a blinking caret while streaming.
/// - `system` — centered caption.
class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    switch (message.role) {
      case 'user':
        return _UserBubble(message: message);
      case 'system':
        return _SystemBubble(message: message);
      case 'assistant':
      default:
        return _AssistantBubble(message: message);
    }
  }
}

class _UserBubble extends StatelessWidget {
  final Message message;

  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.sp4,
            vertical: Tokens.sp3,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Tokens.rXl),
          ),
          child: SelectableText(
            message.content,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final Message message;

  const _AssistantBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.content.isNotEmpty)
          MarkdownBody(
            data: message.content,
            selectable: true,
            styleSheet: _markdownStyle(context),
          ),
        if (message.streaming)
          const Padding(
            padding: EdgeInsets.only(top: Tokens.sp1),
            child: _Caret(),
          ),
      ],
    );
  }

  /// Markdown styles tuned for the app theme: body text uses the theme label
  /// color, code blocks get the system fill, links the accent blue.
  static MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = MarkdownStyleSheet.fromTheme(theme);
    final body = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 15,
      height: 1.5,
      color: scheme.onSurface,
    );
    return base.copyWith(
      p: body,
      strong: body?.copyWith(fontWeight: FontWeight.w700),
      em: body?.copyWith(fontStyle: FontStyle.italic),
      a: body?.copyWith(color: Tokens.accent),
      listBullet: body?.copyWith(color: scheme.onSurface),
      blockquote: body?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.7),
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Tokens.rSm),
      ),
      code: body?.copyWith(
        fontFamily: Tokens.monoStack.split(',').first.trim(),
        fontFamilyFallback: const ['monospace'],
        fontSize: 13,
        height: 1.4,
        color: scheme.onSurface,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
      codeblockDecoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Tokens.rMd),
      ),
      codeblockPadding: const EdgeInsets.all(Tokens.sp3),
      h1: body?.copyWith(
          fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
      h2: body?.copyWith(
          fontSize: 18, fontWeight: FontWeight.w700, height: 1.3),
      h3: body?.copyWith(
          fontSize: 16, fontWeight: FontWeight.w700, height: 1.35),
      h4: body?.copyWith(
          fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
      h5: body?.copyWith(
          fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
      h6: body?.copyWith(
          fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
    );
  }
}

class _SystemBubble extends StatelessWidget {
  final Message message;

  const _SystemBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.sp2),
      child: Center(
        child: Text(
          message.content,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

/// Blinking typing caret shown while an assistant message is streaming.
/// Skips the loop when the user prefers reduced motion (static caret).
class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> {
  static const _blink = Duration(milliseconds: 500);

  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_blink, (_) {
      if (mounted) setState(() => _visible = !_visible);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caret = Container(
      width: 2,
      height: 16,
      decoration: BoxDecoration(
        color: Tokens.accent,
        borderRadius: BorderRadius.circular(1),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return caret;
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.15,
      duration: Tokens.durSlow,
      curve: Curves.easeInOut,
      child: caret,
    );
  }
}
