import 'package:flutter/material.dart';
import '../../models/session.dart';
import '../theme/kimi_theme.dart';

class SessionSidebar extends StatelessWidget {
  final List<KimiSession> sessions;
  final KimiSession? active;
  final ValueChanged<KimiSession> onSelect;
  final VoidCallback onNew;
  final VoidCallback onToggle;
  final bool connected;
  final double? latencyMs;
  final bool connecting;
  final String? error;
  final VoidCallback onReconnect;

  const SessionSidebar({
    super.key,
    required this.sessions,
    required this.active,
    required this.onSelect,
    required this.onNew,
    required this.onToggle,
    required this.connected,
    this.latencyMs,
    required this.connecting,
    this.error,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KimiColors.surface,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(
              children: [
                Text('Sessions', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 20),
                  onPressed: onNew,
                  color: KimiColors.accent,
                  tooltip: 'New session',
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  onPressed: onToggle,
                  color: KimiColors.textDim,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Connection status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected
                        ? KimiColors.success
                        : connecting
                            ? KimiColors.thinking
                            : KimiColors.danger,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    connected
                        ? (latencyMs != null ? '${latencyMs!.toStringAsFixed(0)} ms' : 'Connected')
                        : connecting
                            ? 'Connecting…'
                            : 'Disconnected',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (!connected && !connecting)
                  TextButton(
                    onPressed: onReconnect,
                    child: const Text('Retry', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                error!,
                style: const TextStyle(fontSize: 11, color: KimiColors.danger),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const Divider(height: 1),

          // Session list
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Text(
                      'No sessions yet',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: sessions.length,
                    itemBuilder: (ctx, i) {
                      final s = sessions[i];
                      final isActive = active?.id == s.id;
                      return InkWell(
                        onTap: () => onSelect(s),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive ? KimiColors.surfaceRaised : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isActive
                                ? Border.all(color: KimiColors.hairlineStrong)
                                : null,
                          ),
                          child: Row(
                            children: [
                              if (s.pinned)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(Icons.push_pin_rounded, size: 12, color: KimiColors.thinking),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                        color: KimiColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      s.status.name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _statusColor(s.status),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(SessionStatus s) {
    switch (s) {
      case SessionStatus.streaming:
      case SessionStatus.thinking:
      case SessionStatus.toolRunning:
        return KimiColors.accent;
      case SessionStatus.error:
        return KimiColors.danger;
      case SessionStatus.disconnected:
        return KimiColors.danger;
      default:
        return KimiColors.textDim;
    }
  }
}
