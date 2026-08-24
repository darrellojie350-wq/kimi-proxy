import 'package:flutter/material.dart';
import '../models/session.dart';
import '../theme/tokens.dart';

/// Tool output renderer — terminal for Bash, file preview for Read,
/// diff for Edit/Write, results for Grep, mono fallback otherwise.
class ToolOutputView extends StatelessWidget {
  final ToolEntry tool;
  const ToolOutputView({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mono = TextStyle(
      fontFamily: Tokens.monoStack,
      fontSize: 12,
      height: 1.5,
      color: scheme.onSurface.withValues(alpha: 0.85),
    );

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 320),
      padding: const EdgeInsets.all(Tokens.sp3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Tokens.rMd),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.5), width: 0.5),
      ),
      child: SingleChildScrollView(
        child: switch (tool.name) {
          'Bash' || 'Terminal' => _TerminalView(tool: tool, mono: mono),
          'Read' => _FileView(tool: tool, mono: mono),
          'Write' || 'Edit' => _DiffView(tool: tool, mono: mono),
          'Grep' || 'Search' => _GrepView(tool: tool, mono: mono),
          _ => _FallbackView(tool: tool, mono: mono),
        },
      ),
    );
  }
}

class _TerminalView extends StatelessWidget {
  final ToolEntry tool;
  final TextStyle mono;
  const _TerminalView({required this.tool, required this.mono});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cmd = tool.arguments['command'] ?? tool.arguments['cmd'] ?? '';
    final output = (tool.output ?? '').trimRight();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cmd.toString().isNotEmpty)
          Text(
            '\$ ${cmd.toString()}',
            style: mono.copyWith(
              color: Tokens.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (output.isNotEmpty) ...[
          const SizedBox(height: 6),
          SelectableText(output, style: mono),
        ] else
          Text('(no output)', style: mono.copyWith(color: scheme.onSurface.withValues(alpha: 0.4))),
      ],
    );
  }
}

class _FileView extends StatelessWidget {
  final ToolEntry tool;
  final TextStyle mono;
  const _FileView({required this.tool, required this.mono});

  @override
  Widget build(BuildContext context) {
    final path = tool.arguments['file_path'] ?? tool.arguments['path'] ?? tool.arguments['file'] ?? '';
    final output = (tool.output ?? '').trimRight();
    final lines = output.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (path.toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              path.toString(),
              style: mono.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        for (var i = 0; i < lines.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${i + 1}',
                  textAlign: TextAlign.right,
                  style: mono.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: SelectableText(lines[i], style: mono)),
            ],
          ),
      ],
    );
  }
}

class _DiffView extends StatelessWidget {
  final ToolEntry tool;
  final TextStyle mono;
  const _DiffView({required this.tool, required this.mono});

  @override
  Widget build(BuildContext context) {
    final output = (tool.output ?? '').trimRight();
    if (output.isEmpty) {
      return Text('(no diff)', style: mono.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: output.split('\n').map((line) {
        final Color color;
        final String text;
        if (line.startsWith('+')) {
          color = Tokens.success.withValues(alpha: 0.85);
          text = line;
        } else if (line.startsWith('-')) {
          color = Tokens.danger.withValues(alpha: 0.85);
          text = line;
        } else if (line.startsWith('@@')) {
          color = Tokens.accent;
          text = line;
        } else if (line.startsWith('diff ') || line.startsWith('index ') || line.startsWith('---') || line.startsWith('+++')) {
          color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
          text = line;
        } else {
          color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75);
          text = line;
        }
        return SelectableText(text, style: mono.copyWith(color: color));
      }).toList(),
    );
  }
}

class _GrepView extends StatelessWidget {
  final ToolEntry tool;
  final TextStyle mono;
  const _GrepView({required this.tool, required this.mono});

  @override
  Widget build(BuildContext context) {
    final output = (tool.output ?? '').trimRight();
    final scheme = Theme.of(context).colorScheme;
    if (output.isEmpty) {
      return Text('(no matches)', style: mono.copyWith(color: scheme.onSurface.withValues(alpha: 0.4)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: output.split('\n').map((line) {
        // file:line:content
        final idx = line.indexOf(':');
        final isHeader = idx > 0 && !line.startsWith(' ');
        return SelectableText(
          line,
          style: mono.copyWith(
            color: isHeader ? scheme.onSurface.withValues(alpha: 0.85) : scheme.onSurface.withValues(alpha: 0.6),
            fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
          ),
        );
      }).toList(),
    );
  }
}

class _FallbackView extends StatelessWidget {
  final ToolEntry tool;
  final TextStyle mono;
  const _FallbackView({required this.tool, required this.mono});

  @override
  Widget build(BuildContext context) {
    final output = (tool.output ?? '').trim();
    if (output.isEmpty) {
      return Text('(no output)', style: mono.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)));
    }
    return SelectableText(output, style: mono);
  }
}
