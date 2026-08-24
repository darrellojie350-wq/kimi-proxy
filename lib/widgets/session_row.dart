import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../services/app_state.dart';
import '../theme/tokens.dart';

/// A single session in the sidebar — status dot, name, relative time,
/// pin/delete actions. Selected rows get an accent-tinted fill.
class SessionRow extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;
  final bool selected;

  const SessionRow({
    super.key,
    required this.session,
    required this.onTap,
    this.selected = false,
  });

  Color get _statusColor {
    switch (session.status) {
      case 'streaming':
        return Tokens.accent;
      case 'thinking':
        return Tokens.thinking;
      case 'toolRunning':
        return Tokens.info;
      case 'error':
        return Tokens.danger;
      default:
        return Colors.transparent;
    }
  }

  String get _statusLabel {
    switch (session.status) {
      case 'streaming':
        return 'Streaming';
      case 'thinking':
        return 'Thinking';
      case 'toolRunning':
        return 'Running tools';
      case 'error':
        return 'Error';
      default:
        return 'Idle';
    }
  }

  /// Compact relative time, e.g. "now", "5m ago", "3h ago", "2d ago";
  /// falls back to an intl-formatted date for older sessions.
  String get _relativeTime {
    final local = session.updatedAt.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(local);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = scheme.onSurface.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.7 : 0.55,
    );

    return Material(
      color: selected ? Tokens.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(Tokens.rLg),
      child: ListTile(
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: Tokens.sp3),
        leading: Tooltip(
          message: _statusLabel,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusColor,
              border: _statusColor == Colors.transparent
                  ? Border.all(
                      color: secondary.withValues(alpha: 0.6),
                      width: 1.2,
                    )
                  : null,
            ),
          ),
        ),
        title: Text(
          session.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Tokens.accent : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            _relativeTime,
            style: TextStyle(fontSize: 11, color: secondary),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pin is a local visual toggle only (AppState has no pin API).
            StatefulBuilder(
              builder: (context, setLocal) => _IconAction(
                tooltip: session.pinned ? 'Unpin' : 'Pin',
                icon: session.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: session.pinned
                    ? Tokens.thinking
                    : secondary.withValues(alpha: 0.7),
                onPressed: () =>
                    setLocal(() => session.pinned = !session.pinned),
              ),
            ),
            _IconAction(
              tooltip: 'Delete',
              icon: Icons.delete_outline,
              color: secondary.withValues(alpha: 0.7),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text('“${session.name}” and its history will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Tokens.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) state.deleteSession(session.id);
  }
}

/// Compact circular icon button for trailing row actions.
class _IconAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 16,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      icon: Icon(icon, size: 16, color: color),
    );
  }
}
