import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/message.dart';
import '../theme/kimi_theme.dart';

/// Signature element — expandable tool call card (Warp-inspired blocks).
class ToolCard extends StatefulWidget {
  final ToolCall tool;
  final VoidCallback? onApprove;
  final VoidCallback? onDeny;
  final VoidCallback? onAlways;

  const ToolCard({
    super.key,
    required this.tool,
    this.onApprove,
    this.onDeny,
    this.onAlways,
  });

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> {
  bool _expanded = false;

  Color get _statusColor {
    switch (widget.tool.status) {
      case ToolStatus.pending:
        return KimiColors.textDim;
      case ToolStatus.running:
        return KimiColors.thinking;
      case ToolStatus.success:
        return KimiColors.success;
      case ToolStatus.error:
        return KimiColors.danger;
      case ToolStatus.cancelled:
        return KimiColors.textDim;
    }
  }

  IconData get _statusIcon {
    switch (widget.tool.status) {
      case ToolStatus.pending:
        return Icons.hourglass_empty_rounded;
      case ToolStatus.running:
        return Icons.play_circle_outline_rounded;
      case ToolStatus.success:
        return Icons.check_circle_outline_rounded;
      case ToolStatus.error:
        return Icons.error_outline_rounded;
      case ToolStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsApproval = widget.tool.status == ToolStatus.pending &&
        (widget.onApprove != null || widget.onDeny != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: KimiColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KimiColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(_statusIcon, size: 18, color: _statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.tool.name,
                      style: KimiTheme.mono.copyWith(
                        fontWeight: FontWeight.w600,
                        color: KimiColors.textPrimary,
                      ),
                    ),
                  ),
                  if (widget.tool.status == ToolStatus.running)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: KimiColors.thinking,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: KimiColors.textDim,
                  ),
                ],
              ),
            ),
          ),

          // Expanded body
          if (_expanded) ...[
            const Divider(height: 1, color: KimiColors.hairline),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.tool.arguments.isNotEmpty) ...[
                    Text('Arguments', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: KimiColors.lacquer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SelectableText(
                        widget.tool.arguments.entries
                            .map((e) => '${e.key}: ${e.value}')
                            .join('\n'),
                        style: KimiTheme.monoSmall,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.tool.output != null && widget.tool.output!.isNotEmpty) ...[
                    Row(
                      children: [
                        Text('Output', style: Theme.of(context).textTheme.bodySmall),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          color: KimiColors.textDim,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: widget.tool.output!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
                            );
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 280),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: KimiColors.lacquer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          widget.tool.output!,
                          style: KimiTheme.monoSmall,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Approval bar
          if (needsApproval) ...[
            const Divider(height: 1, color: KimiColors.hairline),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onDeny,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KimiColors.danger,
                        side: const BorderSide(color: KimiColors.danger),
                      ),
                      child: const Text('Deny'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onApprove,
                      child: const Text('Approve'),
                    ),
                  ),
                  if (widget.onAlways != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: widget.onAlways,
                      child: const Text('Always'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
