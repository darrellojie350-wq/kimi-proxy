import 'package:flutter/material.dart';
import '../theme/kimi_theme.dart';

class ThinkingPanel extends StatefulWidget {
  final String content;
  const ThinkingPanel({super.key, required this.content});

  @override
  State<ThinkingPanel> createState() => _ThinkingPanelState();
}

class _ThinkingPanelState extends State<ThinkingPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KimiColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KimiColors.thinking.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.psychology_outlined, size: 16, color: KimiColors.thinking),
                  const SizedBox(width: 8),
                  Text(
                    'Thinking',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: KimiColors.thinking,
                      letterSpacing: 0.3,
                    ),
                  ),
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
