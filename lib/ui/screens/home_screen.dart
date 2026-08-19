import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../models/session.dart';
import '../../models/message.dart';
import '../theme/kimi_theme.dart';
import '../widgets/tool_card.dart';
import '../widgets/thinking_panel.dart';
import '../widgets/session_sidebar.dart';
import '../widgets/composer.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  bool _sidebarOpen = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.activeSession;
    final msgs = session != null ? state.messagesFor(session.id) : <ChatMessage>[];

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _sidebarOpen ? 260 : 0,
            child: _sidebarOpen
                ? SessionSidebar(
                    sessions: state.sessions,
                    active: session,
                    onSelect: state.selectSession,
                    onNew: () => state.createSession(),
                    onToggle: () => setState(() => _sidebarOpen = false),
                    connected: state.bridge.isConnected,
                    latencyMs: state.latencyMs,
                    connecting: state.connecting,
                    error: state.connectionError,
                    onReconnect: state.connect,
                  )
                : const SizedBox.shrink(),
          ),
          if (_sidebarOpen)
            const VerticalDivider(width: 1, color: KimiColors.hairline),

          // Main area
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  session: session,
                  sidebarOpen: _sidebarOpen,
                  onToggleSidebar: () => setState(() => _sidebarOpen = !_sidebarOpen),
                  onInterrupt: state.interrupt,
                  onToggleYolo: state.toggleYolo,
                  onTogglePlan: state.togglePlanMode,
                ),
                Expanded(
                  child: msgs.isEmpty
                      ? _EmptyState(onNew: () => state.createSession())
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          itemCount: msgs.length,
                          itemBuilder: (ctx, i) {
                            final m = msgs[i];
                            return _MessageBlock(
                              message: m,
                              onApprove: (id) => state.approveTool(id),
                              onDeny: (id) => state.denyTool(id),
                              onAlways: (id) => state.approveTool(id, always: true),
                            );
                          },
                        ),
                ),
                Composer(
                  enabled: session != null && state.bridge.isConnected,
                  isStreaming: session?.status == SessionStatus.streaming ||
                      session?.status == SessionStatus.thinking ||
                      session?.status == SessionStatus.toolRunning,
                  onSend: state.sendPrompt,
                  onInterrupt: state.interrupt,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final KimiSession? session;
  final bool sidebarOpen;
  final VoidCallback onToggleSidebar;
  final VoidCallback onInterrupt;
  final VoidCallback onToggleYolo;
  final VoidCallback onTogglePlan;

  const _TopBar({
    required this.session,
    required this.sidebarOpen,
    required this.onToggleSidebar,
    required this.onInterrupt,
    required this.onToggleYolo,
    required this.onTogglePlan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KimiColors.hairline)),
      ),
      child: Row(
        children: [
          if (!sidebarOpen)
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 20),
              onPressed: onToggleSidebar,
              color: KimiColors.textSecondary,
            ),
          Expanded(
            child: Text(
              session?.name ?? 'Kimi Proxy',
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (session != null) ...[
            _Badge(
              label: session!.yolo ? 'YOLO' : 'ASK',
              active: session!.yolo,
              color: session!.yolo ? KimiColors.thinking : KimiColors.textDim,
              onTap: onToggleYolo,
            ),
            const SizedBox(width: 6),
            _Badge(
              label: 'PLAN',
              active: session!.planMode,
              color: KimiColors.accent,
              onTap: onTogglePlan,
            ),
            const SizedBox(width: 8),
            if (session!.status != SessionStatus.idle)
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined, size: 20),
                color: KimiColors.danger,
                onPressed: onInterrupt,
                tooltip: 'Interrupt',
              ),
          ],
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            color: KimiColors.textSecondary,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _Badge({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.5) : KimiColors.hairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? color : KimiColors.textDim,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onNew;
  const _EmptyState({required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.terminal_rounded, size: 48, color: KimiColors.textDim.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Kimi Proxy',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Ultra-low latency remote client for Kimi Code CLI',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Session'),
          ),
        ],
      ),
    );
  }
}

class _MessageBlock extends StatelessWidget {
  final ChatMessage message;
  final void Function(String) onApprove;
  final void Function(String) onDeny;
  final void Function(String) onAlways;

  const _MessageBlock({
    required this.message,
    required this.onApprove,
    required this.onDeny,
    required this.onAlways,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Role label
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isUser
                      ? KimiColors.accent.withValues(alpha: 0.12)
                      : KimiColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isUser ? 'You' : 'Kimi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isUser ? KimiColors.accent : KimiColors.textSecondary,
                  ),
                ),
              ),
              if (message.isStreaming) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: KimiColors.accent),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Thinking
          if (message.hasThinking)
            ThinkingPanel(content: message.reasoningContent!),

          // Tool cards
          if (message.hasTools)
            ...message.toolCalls.map((t) => ToolCard(
                  tool: t,
                  onApprove: t.status == ToolStatus.pending ? () => onApprove(t.id) : null,
                  onDeny: t.status == ToolStatus.pending ? () => onDeny(t.id) : null,
                  onAlways: t.status == ToolStatus.pending ? () => onAlways(t.id) : null,
                )),

          // Content
          if (message.content.isNotEmpty)
            SelectableText(
              message.content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
        ],
      ),
    );
  }
}
