import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Grok-style mode card — rounded surface card with a hairline border and a
/// soft lift + shadow on hover (desktop). Used on the welcome screen.
class ModeCard extends StatelessWidget {
  const ModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = Theme.of(context).textTheme.bodySmall?.color;

    return _HoverCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Tokens.sp3, vertical: Tokens.sp4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: Tokens.accent),
            const SizedBox(height: Tokens.sp2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, height: 1.3, color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded, hairline-bordered surface card with hover lift + shadow.
class _HoverCard extends StatefulWidget {
  const _HoverCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hairline = Theme.of(context).dividerTheme.color ?? scheme.outline;
    return MouseRegion(
      cursor:
          widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Tokens.durBase,
        curve: Curves.easeOutCubic,
        transform: _hovered ? Matrix4.translationValues(0, -2, 0) : null,
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(Tokens.rCard),
          border: Border.all(color: hairline, width: 0.5),
          boxShadow: _hovered ? const [Tokens.shadowCard] : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Tokens.rCard),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(Tokens.rCard),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
