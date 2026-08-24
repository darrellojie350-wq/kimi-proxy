import 'dart:async';

import 'package:flutter/material.dart';

import '../models/session.dart';
import '../theme/tokens.dart';

/// Collapsible "thinking" strip that appears under an assistant message when
/// the model's reasoning / chain-of-thought is present.
///
/// While the message is streaming, a ticking seconds counter shows elapsed
/// thinking time. The expanded view reveals the full reasoning text in a
/// monospace block.
class ThinkingRow extends StatefulWidget {
  final Message message;

  const ThinkingRow({super.key, required this.message});

  @override
  State<ThinkingRow> createState() => _ThinkingRowState();
}

class _ThinkingRowState extends State<ThinkingRow> {
  bool _expanded = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.message.streaming) _startTicker();
  }

  @override
  void didUpdateWidget(covariant ThinkingRow old) {
    super.didUpdateWidget(old);
    if (old.message.streaming != widget.message.streaming) {
      if (widget.message.streaming) {
        _startTicker();
      } else {
        _stopTicker();
      }
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  int get _elapsedSeconds =>
      DateTime.now().difference(widget.message.ts).inSeconds;

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dur = reduceMotion ? Duration.zero : Tokens.durBase;

    final monoStyle = theme.textTheme.bodySmall?.copyWith(
      fontFamily: Tokens.monoStack.split(',').first.trim(),
      fontFamilyFallback: const ['monospace'],
      height: 1.55,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Collapsed / expanded toggle row ---
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Tokens.rLg),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.sp3,
                vertical: Tokens.sp2,
              ),
              decoration: BoxDecoration(
                color: Tokens.thinking.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(Tokens.rLg),
                border: Border.all(
                  color: Tokens.thinking.withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: Tokens.thinking,
                  ),
                  const SizedBox(width: Tokens.sp2),
                  Text(
                    'Thinking',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Tokens.thinking,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.message.streaming) ...[
                    const SizedBox(width: Tokens.sp1),
                    Text(
                      '\u00b7 ${_elapsedSeconds}s',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Tokens.thinking.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: dur,
                    child: const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Tokens.thinking,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // --- Expandable reasoning text ---
        AnimatedSize(
          duration: dur,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: Tokens.sp2),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Tokens.sp3),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(Tokens.rMd),
                    ),
                    child: SelectableText(
                      widget.message.thinking ?? '',
                      style: monoStyle,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
