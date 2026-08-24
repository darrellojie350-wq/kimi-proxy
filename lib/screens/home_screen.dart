import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/composer.dart';
import 'chat_screen.dart';
import 'session_panel.dart';
import 'settings_screen.dart';
import 'welcome_screen.dart';

/// App shell — adaptive layout: persistent sidebar + content on wide screens,
/// drawer-based navigation on phones. Header, content, and composer always
/// visible.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return wide ? _buildWide(context) : _buildNarrow(context);
  }

  // ---- Wide: sidebar + content --------------------------------------------
  Widget _buildWide(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(
          width: Tokens.sidebarWidth,
          child: SessionPanel(),
        ),
        const VerticalDivider(width: 0.5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                showMenuButton: false,
                onMenu: () {},
              ),
              const Expanded(child: _Content()),
              const Composer(),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Narrow: drawer + content -------------------------------------------
  Widget _buildNarrow(BuildContext context) {
    return Scaffold(
      drawer: const Drawer(
        width: Tokens.sidebarWidth,
        child: SessionPanel(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Builder(
            builder: (ctx) => _Header(
              showMenuButton: true,
              onMenu: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          const Expanded(child: _Content()),
          const Composer(),
        ],
      ),
    );
  }
}

/// Content region — welcome state or the active chat.
class _Content extends StatelessWidget {
  const _Content();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.activeSession;
    if (session == null || session.messages.isEmpty) {
      return const WelcomeScreen();
    }
    return const ChatScreen();
  }
}

/// Top navigation bar — menu, session title, model pill, connection badge,
/// settings.
class _Header extends StatelessWidget {
  final bool showMenuButton;
  final VoidCallback onMenu;

  const _Header({required this.showMenuButton, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final online = state.connectionStatus == 'online';

    return Container(
      height: Tokens.headerHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.sp3),
        child: Row(
          children: [
            if (showMenuButton) ...[
              IconButton(
                onPressed: onMenu,
                tooltip: 'Menu',
                iconSize: 22,
                icon: const Icon(Icons.menu),
              ),
              const SizedBox(width: Tokens.sp1),
            ],
            // Brand badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B9CFF), Color(0xFF0F5FD6)],
                ),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15),
            ),
            const SizedBox(width: Tokens.sp2),
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: scheme.onSurface,
                  ),
                  children: [
                    TextSpan(text: state.activeSession?.name ?? 'Kimi Proxy'),
                    if (online)
                      TextSpan(
                        text: ' ●',
                        style: TextStyle(
                          fontSize: 12,
                          color: Tokens.success,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Tokens.sp2),
            // Status label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: online
                    ? Tokens.success.withValues(alpha: 0.12)
                    : Tokens.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (online ? Tokens.success : Tokens.danger).withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Text(
                online ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: online ? Tokens.success : Tokens.danger,
                ),
              ),
            ),
            const SizedBox(width: Tokens.sp2),
            // Model pill
            _ModelPill(
              label: state.activeSession?.model ?? 'kimi',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(width: Tokens.sp1),
            // Settings
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              tooltip: 'Settings',
              iconSize: 22,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small selectable model pill in the header.
class _ModelPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ModelPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurface.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.7 : 0.55,
        );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.rFull),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.sp3,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Tokens.rFull),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: Tokens.monoStack,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 12, color: secondary),
          ],
        ),
      ),
    );
  }
}
