import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Small connection status dot — online (green), connecting (amber, pulsing),
/// offline (red). Mirrors the iOS-style status indicator used across Grok.
class ConnectionBadge extends StatelessWidget {
  final String status; // 'online' | 'connecting' | 'offline'

  const ConnectionBadge({super.key, this.status = 'offline'});

  Color get _color {
    switch (status) {
      case 'online':
        return Tokens.success;
      case 'connecting':
        return Tokens.warning;
      default:
        return Tokens.danger;
    }
  }

  String get _label {
    switch (status) {
      case 'online':
        return 'Connected';
      case 'connecting':
        return 'Connecting…';
      default:
        return 'Offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Tooltip(
      message: _label,
      child: _Pulse(
        enabled: status == 'connecting' && !reduced,
        color: _color,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Pulsing wrapper for the "connecting" state; static when disabled.
class _Pulse extends StatefulWidget {
  final bool enabled;
  final Color color;
  final Widget child;

  const _Pulse({
    required this.enabled,
    required this.color,
    required this.child,
  });

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _opacity = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _Pulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _sync();
  }

  /// Run the pulse only while enabled AND animations are permitted.
  void _sync() {
    final animate = widget.enabled && !MediaQuery.disableAnimationsOf(context);
    if (animate) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
