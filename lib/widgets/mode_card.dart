import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Premium Grok-style mode card — rounded surface, hairline border, hover
/// lift + glow, animated icon color, and a subtle accent ring on hover.
class ModeCard extends StatefulWidget {
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
  State<ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<ModeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = scheme.onSurface.withValues(alpha: 0.55);
    final hairline = Theme.of(context).dividerTheme.color ?? scheme.outline;
    final reduced = MediaQuery.disableAnimationsOf(context);

    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: reduced ? Duration.zero : Tokens.durBase,
        curve: Curves.easeOutCubic,
        transform: _hovered ? Matrix4.translationValues(0, -3, 0) : null,
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(Tokens.rCard),
          border: Border.all(
            color: _hovered ? Tokens.accent : hairline,
            width: _hovered ? 1.2 : 0.5,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Tokens.accent.withValues(alpha: 0.16),
                    blurRadius: 22,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Tokens.rCard),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(Tokens.rCard),
            child: AnimatedContainer(
              duration: reduced ? Duration.zero : Tokens.durBase,
              decoration: BoxDecoration(
                color: _hovered
                    ? Tokens.accentSoft
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(Tokens.rCard),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.sp3, vertical: Tokens.sp4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hovered
                          ? Tokens.accent
                          : Tokens.accentSoft,
                    ),
                    child: Icon(
                      widget.icon,
                      size: 22,
                      color: _hovered ? Colors.white : Tokens.accent,
                    ),
                  ),
                  const SizedBox(height: Tokens.sp2 + 2),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, height: 1.35, color: secondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
