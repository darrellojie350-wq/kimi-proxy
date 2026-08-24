import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/composer.dart';
import '../widgets/connection_badge.dart';
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
            Expanded(
              child: Text(
                state.activeSession?.name ?? 'Kimi Proxy',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: Tokens.sp3),
            _ModelPill(
              label: state.activeSession?.model ?? 'kimi',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(width: Tokens.sp3),
            ConnectionBadge(status: state.connectionStatus),
            const SizedBox(width: Tokens.sp1),
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
