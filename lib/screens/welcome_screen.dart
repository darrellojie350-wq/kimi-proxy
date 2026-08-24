import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/connection_badge.dart';
import '../widgets/mode_card.dart';

/// Welcome / empty-state screen — Grok-style centered hero with mode cards,
/// starter chips and an offline connection card.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final textTheme = Theme.of(context).textTheme;
    final online = state.connectionStatus == 'online';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: Tokens.sp4, vertical: Tokens.sp8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Kicker
              const Text(
                'KIMI CODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.2,
                  color: Tokens.accent,
                ),
              ),
              const SizedBox(height: Tokens.sp2),
              // Hero
              Text('Ask anything',
                  style: textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: Tokens.sp1),
              Text(
                'Chat, code, debug and research with Kimi Code.',
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Tokens.sp6),
              const _ModeGrid(),
              const SizedBox(height: Tokens.sp5),
              const _StarterChips(),
              if (!online) ...[
                const SizedBox(height: Tokens.sp6),
                _ConnectionCard(status: state.connectionStatus),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Mode cards grid --------------------------------------------------------

class _ModeGrid extends StatelessWidget {
  const _ModeGrid();

  static const List<_Mode> _kModes = [
    _Mode(
      icon: Icons.chat_bubble_outline,
      title: 'Assistant',
      subtitle: 'Chat, code, answer',
      prompt:
          'You are my general assistant. Help with code, answer questions clearly, and keep responses concise.',
    ),
    _Mode(
      icon: Icons.account_tree_outlined,
      title: 'Plan',
      subtitle: 'Design before acting',
      prompt:
          'Plan this task before acting: analyze the goal, design the approach, and outline a step-by-step plan before writing code.',
    ),
    _Mode(
      icon: Icons.bug_report_outlined,
      title: 'Debug',
      subtitle: 'Find and fix errors',
      prompt:
          'Debug the current error: investigate the root cause, explain what went wrong, then apply a minimal fix.',
    ),
    _Mode(
      icon: Icons.travel_explore,
      title: 'Research',
      subtitle: 'Search and synthesize',
      prompt:
          'Research this topic across sources and synthesize the findings into a clear, well-cited summary.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 460;
      if (narrow) {
        final w = (constraints.maxWidth - Tokens.sp2) / 2;
        return Wrap(
          spacing: Tokens.sp2,
          runSpacing: Tokens.sp2,
          children: [
            for (final m in _kModes) SizedBox(width: w, child: _card(m, state))
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < _kModes.length; i++) ...[
              if (i > 0) const SizedBox(width: Tokens.sp2),
              Expanded(child: _card(_kModes[i], state)),
            ]
          ],
        ),
      );
    });
  }

  Widget _card(_Mode m, AppState state) => ModeCard(
        icon: m.icon,
        title: m.title,
        subtitle: m.subtitle,
        onTap: () => state.sendPrompt(m.prompt),
      );
}

/// Record-like data class for mode card content.
class _Mode {
  final IconData icon;
  final String title;
  final String subtitle;
  final String prompt;

  const _Mode({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.prompt,
  });
}

// ---- Starter chips ----------------------------------------------------------

class _StarterChips extends StatelessWidget {
  const _StarterChips();

  static const List<String> _kChips = [
    'Explain this codebase',
    'Plan a feature',
    'Debug an error',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hairline = Theme.of(context).dividerTheme.color ?? scheme.outline;
    final chipColor =
        dark ? Tokens.darkSecondaryLabel : Tokens.lightSecondaryLabel;
    return Wrap(
      spacing: Tokens.sp2,
      runSpacing: Tokens.sp2,
      alignment: WrapAlignment.center,
      children: [
        for (final c in _kChips)
          Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(Tokens.rFull),
            child: InkWell(
              borderRadius: BorderRadius.circular(Tokens.rFull),
              onTap: () => state.sendPrompt(c),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.sp3 + 2,
                  vertical: Tokens.sp2 - 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Tokens.rFull),
                  border: Border.all(color: hairline, width: 0.5),
                ),
                child: Text(
                  c,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: chipColor,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---- Offline connection card ------------------------------------------------

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final hairline = Theme.of(context).dividerTheme.color ?? scheme.outline;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Tokens.sp4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Tokens.rCard),
        border: Border.all(color: hairline, width: 0.5),
      ),
      child: Row(
        children: [
          ConnectionBadge(status: status),
          const SizedBox(width: Tokens.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bridge offline', style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Connect to the bridge to start chatting.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: Tokens.sp3),
          FilledButton.icon(
            onPressed: () => state.connect(),
            icon: const Icon(Icons.link_rounded, size: 15),
            label: const Text('Connect to bridge'),
          ),
        ],
      ),
    );
  }
}
