import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/connection_badge.dart';
import '../widgets/mode_card.dart';

/// Welcome / empty-state — premium Grok-style landing:
/// glowing brand, hero, rich mode cards, suggestion chips, recent sessions,
/// keyboard hints, and a polished connection card when offline.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )..forward();
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final textTheme = Theme.of(context).textTheme;

    final online = state.connectionStatus == 'online';
    final reduced = MediaQuery.disableAnimationsOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.sp5,
        vertical: Tokens.sp8,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BrandGlow(reduced: reduced),
                const SizedBox(height: Tokens.sp6),
                Text(
                  'Ask anything',
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Tokens.sp2),
                Text(
                  'Chat, code, debug and research with Kimi Code.',
                  style: textTheme.bodySmall?.copyWith(fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Tokens.sp8),
                const _ModeGrid(),
                const SizedBox(height: Tokens.sp6),
                const _SuggestionRow(),
                if (state.sessions.length > 1) ...[
                  const SizedBox(height: Tokens.sp6),
                  _RecentSessions(sessions: state.sessions),
                ],
                const SizedBox(height: Tokens.sp5),
                const _KbdHints(),
                if (!online) ...[
                  const SizedBox(height: Tokens.sp6),
                  _ConnectionCard(status: state.connectionStatus),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsing brand glow behind the "Kimi" mark.
class _BrandGlow extends StatefulWidget {
  final bool reduced;
  const _BrandGlow({required this.reduced});

  @override
  State<_BrandGlow> createState() => _BrandGlowState();
}

class _BrandGlowState extends State<_BrandGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    if (!widget.reduced) _c.repeat(reverse: true);
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
      builder: (context, child) {
        final glow = 0.25 + _c.value * 0.30;
        return Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Tokens.accent.withValues(alpha: glow),
                Tokens.accent.withValues(alpha: 0.0),
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B9CFF), Color(0xFF0F5FD6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Tokens.accent.withValues(alpha: 0.45),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 30),
          ),
        );
      },
    );
  }
}

// ---- Mode cards grid --------------------------------------------------------

class _ModeGrid extends StatelessWidget {
  const _ModeGrid();

  static const List<_Mode> _kModes = [
    _Mode(
      icon: Icons.chat_bubble_outline_rounded,
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
      icon: Icons.travel_explore_rounded,
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
      final narrow = constraints.maxWidth < 520;
      if (narrow) {
        final w = (constraints.maxWidth - Tokens.sp3) / 2;
        return Wrap(
          spacing: Tokens.sp3,
          runSpacing: Tokens.sp3,
          children: [
            for (final m in _kModes)
              SizedBox(width: w, child: _card(m, state)),
          ],
        );
      }
      return Row(
        children: [
          for (var i = 0; i < _kModes.length; i++) ...[
            if (i > 0) const SizedBox(width: Tokens.sp3),
            Expanded(child: _card(_kModes[i], state)),
          ],
        ],
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

// ---- Suggestion chips -------------------------------------------------------

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow();

  static const List<({IconData icon, String label})> _kChips = [
    (icon: Icons.terminal_rounded, label: 'Explain this codebase'),
    (icon: Icons.flag_outlined, label: 'Plan a feature'),
    (icon: Icons.bug_report_outlined, label: 'Debug an error'),
    (icon: Icons.edit_note_rounded, label: 'Write a test'),
    (icon: Icons.bolt_outlined, label: 'Optimize performance'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chipColor = dark ? Tokens.darkSecondaryLabel : Tokens.lightSecondaryLabel;
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
              onTap: () => state.sendPrompt(c.label),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.sp3 + 2, vertical: Tokens.sp2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Tokens.rFull),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.6), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(c.icon, size: 13, color: Tokens.accent),
                    const SizedBox(width: 6),
                    Text(c.label,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: chipColor)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---- Recent sessions ----------------------------------------------------------

class _RecentSessions extends StatelessWidget {
  final List sessions;
  const _RecentSessions({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final recent = sessions.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: Tokens.sp2),
          child: Text(
            'RECENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: scheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(Tokens.rCard),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.5), width: 0.5),
          ),
          child: Column(
            children: [
              for (var i = 0; i < recent.length; i++) ...[
                if (i > 0)
                  Divider(height: 0.5, thickness: 0.5,
                      color: scheme.outline.withValues(alpha: 0.4)),
                InkWell(
                  onTap: () => state.selectSessionById(recent[i].id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Tokens.sp4, vertical: Tokens.sp3),
                    child: Row(
                      children: [
                        Icon(Icons.history_rounded, size: 16,
                            color: scheme.onSurface.withValues(alpha: 0.4)),
                        const SizedBox(width: Tokens.sp3),
                        Expanded(
                          child: Text(
                            (recent[i] as dynamic).name as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(fontSize: 14),
                          ),
                        ),
                        Text(
                          _relTime((recent[i] as dynamic).updatedAt as DateTime),
                          style: textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                        const SizedBox(width: Tokens.sp1),
                        Icon(Icons.chevron_right, size: 16,
                            color: scheme.onSurface.withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _relTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

// ---- Keyboard hints ------------------------------------------------------------

class _KbdHints extends StatelessWidget {
  const _KbdHints();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.4);
    Widget kbd(String label) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.6), width: 0.5),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 10.5, color: muted, fontWeight: FontWeight.w600)),
        );
    return Wrap(
      spacing: Tokens.sp3,
      runSpacing: Tokens.sp2,
      alignment: WrapAlignment.center,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [kbd('⌘'), const SizedBox(width: 2), kbd('N'), const SizedBox(width: 5), Text('New chat', style: TextStyle(fontSize: 11.5, color: muted))]),
        Row(mainAxisSize: MainAxisSize.min, children: [kbd('⌘'), const SizedBox(width: 2), kbd('K'), const SizedBox(width: 5), Text('Command', style: TextStyle(fontSize: 11.5, color: muted))]),
      ],
    );
  }
}

// ---- Offline connection card ------------------------------------------------------

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Tokens.sp4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Tokens.rCard),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.6), width: 0.5),
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
          FilledButton.icon(
            onPressed: () => state.connect(),
            icon: const Icon(Icons.link_rounded, size: 15),
            label: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
