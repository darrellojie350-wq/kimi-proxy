import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/connection_badge.dart';
import '../widgets/session_row.dart';

/// Sidebar session list — brand header, search, session rows, footer with
/// connection status and a connect action when offline.
class SessionPanel extends StatelessWidget {
  const SessionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _BrandHeader(),
            const Expanded(child: _SessionList()),
            const _PanelFooter(),
          ],
        ),
      ),
    );
  }
}

/// Brand mark + new-chat action.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.sp4, Tokens.sp3, Tokens.sp2, Tokens.sp2),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B9CFF), Color(0xFF0F5FD6)],
              ),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: Tokens.sp2),
          const Text(
            'Kimi Proxy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => context.read<AppState>().createSession(),
            tooltip: 'New chat',
            visualDensity: VisualDensity.compact,
            iconSize: 22,
            icon: const Icon(Icons.add_circle_rounded),
            color: Tokens.accent,
          ),
        ],
      ),
    );
  }
}

/// Search field + filtered session rows. Stateful so the query and
/// controller live with the list.
class _SessionList extends StatefulWidget {
  const _SessionList();

  @override
  State<_SessionList> createState() => _SessionListState();
}

class _SessionListState extends State<_SessionList> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// Group sessions into Today / Yesterday / Earlier with section labels.
  List<Widget> _groupedRows(AppState state, List sessions) {
    final now = DateTime.now();
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      color: scheme.onSurface.withValues(alpha: 0.4),
    );
    final rows = <Widget>[];
    String? currentGroup;

    for (final s in sessions) {
      final t = s.updatedAt;
      final group = _groupOf(now, t);
      if (group != currentGroup) {
        currentGroup = group;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.sp3, Tokens.sp2, Tokens.sp3, 4),
          child: Text(group, style: labelStyle),
        ));
      }
      final active = state.activeSession?.id == s.id ||
          (s.serverId != null && state.activeSession?.serverId == s.serverId);
      rows.add(SessionRow(
        session: s,
        selected: active,
        onTap: () => state.selectSessionById(s.id),
      ));
    }
    return rows;
  }

  String _groupOf(DateTime now, DateTime t) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    if (diff < 7) return 'THIS WEEK';
    return 'EARLIER';
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final secondary = Theme.of(context).colorScheme.onSurface.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.7 : 0.55,
        );

    final query = _query.trim().toLowerCase();
    final sessions = query.isEmpty
        ? state.sessions
        : state.sessions
            .where((s) => s.name.toLowerCase().contains(query))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.sp3,
            0,
            Tokens.sp3,
            Tokens.sp2,
          ),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search sessions',
              prefixIcon: const Icon(Icons.search, size: 18),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Tokens.sp3,
                vertical: Tokens.sp2,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close, size: 16),
                      visualDensity: VisualDensity.compact,
                    ),
            ),
          ),
        ),
        const Divider(height: 0.5),
        // Rows (grouped by day)
        Expanded(
          child: sessions.isEmpty
              ? Center(
                  child: Text(
                    query.isEmpty ? 'No sessions yet' : 'No matches',
                    style: TextStyle(fontSize: 13, color: secondary),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.sp2,
                    vertical: Tokens.sp2,
                  ),
                  children: _groupedRows(state, sessions),
                ),
        ),
      ],
    );
  }
}

/// Connection status + connect action.
class _PanelFooter extends StatelessWidget {
  const _PanelFooter();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final secondary = Theme.of(context).colorScheme.onSurface.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.7 : 0.55,
        );
    final online = state.connectionStatus == 'online';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 0.5),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.sp4,
            Tokens.sp2,
            Tokens.sp4,
            Tokens.sp2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ConnectionBadge(status: state.connectionStatus),
                  const SizedBox(width: Tokens.sp2),
                  Expanded(
                    child: Text(
                      _statusText(state.connectionStatus),
                      style: TextStyle(fontSize: 12, color: secondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!online)
                    TextButton(
                      onPressed: () => state.connect(),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: Tokens.sp2,
                        ),
                        minimumSize: const Size(0, 30),
                        foregroundColor: Tokens.accent,
                      ),
                      child: const Text(
                        'Connect',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
              if (!online)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    state.bridgeUrl,
                    style: TextStyle(
                      fontSize: 10,
                      color: secondary.withValues(alpha: 0.8),
                      fontFamily: Tokens.monoStack,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'online':
        return 'Bridge connected';
      case 'connecting':
        return 'Connecting…';
      default:
        return 'Bridge offline';
    }
  }
}
