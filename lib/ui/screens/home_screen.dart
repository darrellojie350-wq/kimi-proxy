import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../services/bridge_service.dart';
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
  bool _sidebarOpen = false; // mobile-first: closed by default

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      // Only auto-connect if not mixed-content blocked
      if (!BridgeService.isMixedContentBlocked(state.bridgeUrl ?? '')) {
        state.connect();
      }
    });
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _ensureSessionAndSend(AppState state, String text) async {
    if (!state.bridge.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not connected — open Settings and Connect'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _openSettings();
      return;
    }
    if (state.activeSession == null) {
      state.createSession(name: 'Chat');
      // Wait briefly for session.created
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (state.activeSession != null) {
      state.sendPrompt(text);
      // scroll to bottom after send
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.activeSession;
    final msgs = session != null ? state.messagesFor(session.id) : <ChatMessage>[];
    final mixed = BridgeService.isMixedContentBlocked(state.bridgeUrl ?? '');
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;

    // Auto-open sidebar on desktop
    final showSidebar = isWide ? true : _sidebarOpen;

    return Scaffold(
      body: Column(
        children: [
          // Direct API mode: chat works without VPS bridge / no mixed-content block
          Expanded(
            child: Row(
              children: [
                if (showSidebar) ...[
                  SizedBox(
                    width: isWide ? 260 : 280,
                    child: SessionSidebar(
                      sessions: state.sessions,
                      active: session,
                      onSelect: (s) {
                        state.selectSession(s);
                        if (!isWide) setState(() => _sidebarOpen = false);
                      },
                      onNew: () {
                        state.createSession();
                        if (!isWide) setState(() => _sidebarOpen = false);
                      },
                      onToggle: () => setState(() => _sidebarOpen = false),
                      connected: true, // direct API path is active
                      latencyMs: state.latencyMs,
                      connecting: state.connecting,
                      error: state.connectionError,
                      onReconnect: () {
                        if (mixed) {
                          _openSettings();
                        } else {
                          state.connect();
                        }
                      },
                    ),
                  ),
                  const VerticalDivider(width: 1, color: KimiColors.hairline),
                ],
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        session: session,
                        sidebarOpen: showSidebar,
                        connected: state.bridge.isConnected,
                        connecting: state.connecting,
                        onToggleSidebar: () =>
                            setState(() => _sidebarOpen = !_sidebarOpen),
                        onInterrupt: state.interrupt,
                        onToggleYolo: state.toggleYolo,
                        onTogglePlan: state.togglePlanMode,
                        onSettings: _openSettings,
                      ),
                      Expanded(
                        child: msgs.isEmpty
                            ? _EmptyState(
                                connected: true,
                                mixed: mixed,
                                onNew: () => state.createSession(),
                                onSettings: _openSettings,
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                itemCount: msgs.length,
                                itemBuilder: (ctx, i) {
                                  final m = msgs[i];
                                  return _MessageBlock(
                                    message: m,
                                    onApprove: (id) => state.approveTool(id),
                                    onDeny: (id) => state.denyTool(id),
                                    onAlways: (id) =>
                                        state.approveTool(id, always: true),
                                  );
                                },
                              ),
                      ),
                      Composer(
                        connected: true, // direct mode always available
                        hasSession: session != null,
                        isStreaming: state.isGenerating ||
                            session?.status == SessionStatus.streaming ||
                            session?.status == SessionStatus.thinking ||
                            session?.status == SessionStatus.toolRunning,
                        onSend: (text) => state.sendPrompt(text),
                        onInterrupt: state.interrupt,
                        onNeedConnect: null,
                        onNeedSession: () => state.createSession(name: 'Chat'),
                      ),
                    ],
                  ),
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
  final bool connected;
  final bool connecting;
  final VoidCallback onToggleSidebar;
  final VoidCallback onInterrupt;
  final VoidCallback onToggleYolo;
  final VoidCallback onTogglePlan;
  final VoidCallback onSettings;

  const _TopBar({
    required this.session,
    required this.sidebarOpen,
    required this.connected,
    required this.connecting,
    required this.onToggleSidebar,
    required this.onInterrupt,
    required this.onToggleYolo,
    required this.onTogglePlan,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KimiColors.hairline)),
      ),
      child: Row(
        children: [
          if (!sidebarOpen)
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 22),
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
          // Connection pill
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: connected
                  ? KimiColors.success.withValues(alpha: 0.15)
                  : KimiColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              connecting
                  ? '…'
                  : connected
                      ? 'LIVE'
                      : 'OFF',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: connected ? KimiColors.success : KimiColors.danger,
              ),
            ),
          ),
          if (session != null) ...[
            _Badge(
              label: session!.yolo ? 'YOLO' : 'ASK',
              active: session!.yolo,
              color: session!.yolo ? KimiColors.thinking : KimiColors.textDim,
              onTap: onToggleYolo,
            ),
            const SizedBox(width: 4),
            _Badge(
              label: 'PLAN',
              active: session!.planMode,
              color: KimiColors.accent,
              onTap: onTogglePlan,
            ),
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
            onPressed: onSettings,
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
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
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: active ? color : KimiColors.textDim,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool connected;
  final bool mixed;
  final VoidCallback onNew;
  final VoidCallback onSettings;

  const _EmptyState({
    required this.connected,
    required this.mixed,
    required this.onNew,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal_rounded,
                size: 48, color: KimiColors.textDim.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Kimi Proxy', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Type below to chat · New Session in the menu',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (connected)
              ElevatedButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Session'),
              )
            else
              ElevatedButton.icon(
                onPressed: onSettings,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Open Settings'),
              ),
          ],
        ),
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
                    color:
                        isUser ? KimiColors.accent : KimiColors.textSecondary,
                  ),
                ),
              ),
              if (message.isStreaming) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: KimiColors.accent,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (message.hasThinking)
            ThinkingPanel(content: message.reasoningContent!, isLive: message.isStreaming),
          if (message.isStreaming && message.content.isEmpty && !message.hasThinking)
            const Padding(padding: EdgeInsets.only(bottom: 12), child: StreamingDots()),
          if (message.hasTools)
            ...message.toolCalls.map(
              (t) => ToolCard(
                tool: t,
                onApprove:
                    t.status == ToolStatus.pending ? () => onApprove(t.id) : null,
                onDeny:
                    t.status == ToolStatus.pending ? () => onDeny(t.id) : null,
                onAlways:
                    t.status == ToolStatus.pending ? () => onAlways(t.id) : null,
              ),
            ),
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
