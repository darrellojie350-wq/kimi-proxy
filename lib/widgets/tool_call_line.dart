import 'dart:async';
import 'package:flutter/material.dart';
import '../models/session.dart';
import '../theme/tokens.dart';
import 'tool_output_view.dart';

/// Quiet, borderless tool-call line (Grok/Kimi style): icon, name, args
/// preview, status dot, duration. Tap expands the tool output inline.
class ToolCallLine extends StatefulWidget {
  final ToolEntry tool;
  const ToolCallLine({super.key, required this.tool});

  @override
  State<ToolCallLine> createState() => _ToolCallLineState();
}

class _ToolCallLineState extends State<ToolCallLine>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _pulse;
  Timer? _tick;

  IconData get _icon => switch (widget.tool.name) {
        'Bash' || 'Terminal' => Icons.terminal,
        'Read' => Icons.description_outlined,
        'Write' || 'Edit' => Icons.edit_outlined,
        'Glob' => Icons.folder_open,
        'Grep' || 'Search' => Icons.search,
        'WebSearch' => Icons.language,
        'FetchURL' || 'Fetch' => Icons.link,
        _ => Icons.code,
      };

  Color get _dotColor {
    switch (widget.tool.status) {
      case 'running':
        return _pulse.isAnimating ? _pulseColor : Tokens.accent;
      case 'success':
        return Tokens.success;
      case 'failed':
        return Tokens.danger;
      default:
        return Tokens.darkSecondaryLabel;
    }
  }

  Color get _pulseColor {
    final v = _pulse.value;
    return Color.lerp(Tokens.accent, Tokens.accent.withValues(alpha: 0.25), v)!;
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncPulse();
  }

  void _syncPulse() {
    final running = widget.tool.status == 'running';
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (running && !reduced) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant ToolCallLine old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _tick?.cancel();
    super.dispose();
  }

  String get _durationLabel {
    final d = widget.tool.durationMs;
    if (d == null) return '';
    final s = d / 1000;
    return '· ${s.toStringAsFixed(s < 10 ? 1 : 0)}s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = scheme.onSurface.withValues(alpha: 0.6);
    final tool = widget.tool;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final running = tool.status == 'running';
        final dotColor = running ? _pulseColor : _dotColor;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(Tokens.rMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.sp3, vertical: 6),
                child: Row(
                  children: [
                    Icon(_icon, size: 15, color: secondary),
                    const SizedBox(width: Tokens.sp2),
                    Text(
                      tool.name,
                      style: TextStyle(
                        fontFamily: Tokens.monoStack,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: Tokens.sp2),
                    Expanded(
                      child: Text(
                        tool.argsPreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: Tokens.monoStack,
                          fontSize: 11,
                          color: secondary,
                        ),
                      ),
                    ),
                    if (_durationLabel.isNotEmpty && !running)
                      Padding(
                        padding: const EdgeInsets.only(right: Tokens.sp2),
                        child: Text(
                          _durationLabel,
                          style: TextStyle(fontSize: 11, color: secondary),
                        ),
                      ),
                    AnimatedSwitcher(
                      duration: Tokens.durBase,
                      child: running
                          ? Container(
                              key: const ValueKey('running'),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            )
                          : Icon(
                              tool.status == 'success'
                                  ? Icons.check_circle
                                  : tool.status == 'failed'
                                      ? Icons.cancel
                                      : Icons.circle,
                              key: ValueKey(tool.status),
                              size: 13,
                              color: dotColor,
                            ),
                    ),
                    const SizedBox(width: Tokens.sp2),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: Tokens.durBase,
                      child: Icon(Icons.chevron_right, size: 14, color: secondary),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: Tokens.durBase,
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(
                        left: Tokens.sp8,
                        right: Tokens.sp4,
                        bottom: Tokens.sp2,
                      ),
                      child: ToolOutputView(tool: tool),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}
