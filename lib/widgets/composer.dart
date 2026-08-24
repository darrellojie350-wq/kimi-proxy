import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../services/app_state.dart';
import '../theme/tokens.dart';

/// Premium iOS-style composer — segmented mode control, multi-line input with
/// Enter to send, gradient send/stop button with context ring, attach, voice.
class Composer extends StatefulWidget {
  const Composer({super.key});

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final TextEditingController _controller = TextEditingController();
  bool _think = true;

  @override
  void initState() {
    super.initState();
    _think = context.read<AppState>().activeSession?.thinkingEnabled ?? true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static bool _isBusy(Session? s) {
    final status = s?.status ?? 'idle';
    return status == 'streaming' || status == 'thinking' || status == 'toolRunning';
  }

  void _submit() {
    final state = context.read<AppState>();
    final text = _controller.text.trim();
    if (text.isEmpty || state.connectionStatus != 'online') return;
    if (_isBusy(state.activeSession)) return;
    state.sendPrompt(text);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hairline = Theme.of(context).dividerTheme.color ?? scheme.outline;
    final hintColor = dark ? Tokens.darkTertiaryLabel : Tokens.lightTertiaryLabel;
    final session = state.activeSession;
    final online = state.connectionStatus == 'online';
    final busy = _isBusy(session);
    final canSend = online && _controller.text.trim().isNotEmpty && !busy;
    final msgCount = (session?.messages.length ?? 0);
    final ctxPct = (msgCount % 100) / 100.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.sp3, Tokens.sp2, Tokens.sp3, Tokens.sp2),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Tokens.contentMaxWidth),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(Tokens.rComposer),
              border: Border.all(color: hairline, width: 0.5),
              boxShadow: const [Tokens.shadowCard],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mode segmented row
                _buildModeRow(state, session, scheme, dark),
                const SizedBox(height: 8),
                // Input row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Attach
                    _IconBtn(Icons.attach_file_rounded, hintColor, 'Attach'),
                    const SizedBox(width: 4),
                    Expanded(child: _buildField()),
                    const SizedBox(width: 6),
                    // Send/Stop with context ring
                    _buildAction(state, canSend, busy, ctxPct, scheme),
                  ],
                ),
                const SizedBox(height: 6),
                // Footer hints
                Row(
                  children: [
                    if (online)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        _kbd('↵', hintColor),
                        const SizedBox(width: 2),
                        Text('send', style: TextStyle(fontSize: 10.5, color: hintColor)),
                        const SizedBox(width: 12),
                        _kbd('⇧↵', hintColor),
                        const SizedBox(width: 2),
                        Text('newline', style: TextStyle(fontSize: 10.5, color: hintColor)),
                      ])
                    else
                      Text('Offline — connect in Settings',
                          style: TextStyle(fontSize: 10.5, color: hintColor)),
                    const Spacer(),
                    Text('$msgCount msgs',
                        style: TextStyle(fontSize: 10.5, color: hintColor)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kbd(String label, Color hint) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: hint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: hint.withValues(alpha: 0.25), width: 0.5),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: hint)),
      );

  // ---- Mode segmented control --------------------------------------------------
  Widget _buildModeRow(AppState state, Session? session, ColorScheme scheme, bool dark) {
    final yolo = session?.yolo ?? false;
    final plan = session?.planMode ?? false;
    final auto = !yolo && !plan;
    return Row(
      children: [
        _segPillBtn('YOLO', yolo, () => state.config(yolo: !yolo), scheme, dark),
        const SizedBox(width: 4),
        _segPillBtn('Plan', plan, () => state.config(planMode: !plan), scheme, dark),
        const SizedBox(width: 4),
        _segPillBtn('Auto', auto, () => state.config(yolo: false, planMode: false), scheme, dark),
        const SizedBox(width: 4),
        _segPillBtn('Think', _think, () => setState(() => _think = !_think), scheme, dark),
        const Spacer(),
        // Voice hint
        Icon(Icons.mic_rounded, size: 15, color: scheme.onSurface.withValues(alpha: 0.25)),
      ],
    );
  }

  Widget _segPillBtn(String label, bool selected, VoidCallback onTap, ColorScheme scheme, bool dark) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Tokens.durBase,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Tokens.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: selected
              ? null
              : Border.all(color: scheme.outline.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }

  // ---- Text field --------------------------------------------------------------
  Widget _buildField() {
    return Focus(
      onKeyEvent: (node, event) {
        if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed) {
          _submit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: _controller,
        minLines: 1,
        maxLines: 6,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 15, height: 1.45),
        decoration: const InputDecoration(
          hintText: 'Ask anything…',
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  // ---- Send / Stop with context ring -------------------------------------------
  Widget _buildAction(AppState state, bool canSend, bool busy, double pct, ColorScheme scheme) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Context ring
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 1.8,
              color: Tokens.accent.withValues(alpha: 0.5),
              backgroundColor: scheme.outline.withValues(alpha: 0.15),
            ),
          ),
          // Button
          GestureDetector(
            onTap: busy ? () => state.interrupt() : (canSend ? _submit : null),
            child: AnimatedContainer(
              duration: Tokens.durBase,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: busy
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3B9CFF), Color(0xFF0F5FD6)],
                      ),
                color: busy ? Tokens.danger : null,
                boxShadow: [
                  BoxShadow(
                    color: (busy ? Tokens.danger : Tokens.accent).withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                busy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                size: 17,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _IconBtn(this.icon, this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}