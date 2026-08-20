import 'package:flutter/material.dart';
import '../theme/kimi_theme.dart';

class ThinkingPanel extends StatefulWidget {
  final String content;
  final bool isLive;
  const ThinkingPanel({super.key, required this.content, this.isLive = false});

  @override
  State<ThinkingPanel> createState() => _ThinkingPanelState();
}

class _ThinkingPanelState extends State<ThinkingPanel>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KimiColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KimiColors.thinking.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  FadeTransition(
                    opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
                    child: const Icon(Icons.auto_awesome, size: 16, color: KimiColors.thinking),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isLive ? 'Thinking…' : 'Thinking',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: KimiColors.thinking,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (widget.isLive) ...[
                    const SizedBox(width: 8),
                    _DotPulse(controller: _pulse),
                  ],
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: KimiColors.textDim,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: KimiColors.hairline),
            Padding(
              padding: const EdgeInsets.all(14),
              child: SelectableText(
                widget.content,
                style: KimiTheme.monoSmall.copyWith(
                  color: KimiColors.textSecondary,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DotPulse extends StatelessWidget {
  final AnimationController controller;
  const _DotPulse({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (controller.value + i * 0.2) % 1.0;
            final o = 0.3 + 0.7 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.only(right: 3),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: KimiColors.thinking.withValues(alpha: o),
              ),
            );
          }),
        );
      },
    );
  }
}

class StreamingDots extends StatefulWidget {
  const StreamingDots({super.key});
  @override
  State<StreamingDots> createState() => _StreamingDotsState();
}

class _StreamingDotsState extends State<StreamingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_c.value + i / 3) % 1.0;
            final y = (phase < 0.5 ? phase : 1 - phase) * -6;
            return Transform.translate(
              offset: Offset(0, y),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: KimiColors.accent.withValues(alpha: 0.7 + 0.3 * (1 - phase)),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
