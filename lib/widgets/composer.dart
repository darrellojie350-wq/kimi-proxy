import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../services/app_state.dart';
import '../theme/tokens.dart';

/// Composer — the input bar with mode pills (YOLO / Plan / Auto / Think),
/// a growing multi-line text field, a context ring behind the send/stop
/// button, and a hint row. Styled like a premium iOS input field.
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
    return status == 'streaming' ||
        status == 'thinking' ||
        status == 'toolRunning';
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

  void _toggleThink() {
    setState(() => _think = !_think);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hairline = Theme.of(context).dividerTheme.color ?? scheme.outline;
    final hintColor =
        dark ? Tokens.darkTertiaryLabel : Tokens.lightTertiaryLabel;
    final session = state.activeSession;
    final online = state.connectionStatus == 'online';
    final busy = _isBusy(session);
    final canSend = online && _controller.text.trim().isNotEmpty && !busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Tokens.sp3, Tokens.sp2, Tokens.sp3, Tokens.sp2),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Tokens.contentMaxWidth),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
                Tokens.sp3, Tokens.sp2, Tokens.sp3, Tokens.sp1 + 2),
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
                _buildPills(state, session),
                const SizedBox(height: Tokens.sp1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _buildField()),
                    const SizedBox(width: Tokens.sp2),
                    _buildAction(state,
                        online: online, busy: busy, canSend: canSend),
                  ],
                ),
                const SizedBox(height: Tokens.sp1),
                Text(
                  online
                      ? 'Enter to send · Shift+Enter newline'
                      : 'Offline — connect to bridge',
                  style: TextStyle(fontSize: 11, color: hintColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Mode pills ---------------------------------------------------------
  Widget _buildPills(AppState state, Session? session) {
    final yolo = session?.yolo ?? false;
    final plan = session?.planMode ?? false;
    return Wrap(
      spacing: Tokens.sp1,
      runSpacing: Tokens.sp1,
      children: [
        _ModePill(
          label: 'YOLO',
          selected: yolo,
          onTap: () => state.config(yolo: !yolo),
        ),
        _ModePill(
          label: 'Plan',
          selected: plan,
          onTap: () => state.config(planMode: !plan),
        ),
        _ModePill(
          label: 'Auto',
          selected: !yolo && !plan,
          onTap: () => state.config(yolo: false, planMode: false),
        ),
        _ModePill(label: 'Think', selected: _think, onTap: _toggleThink),
      ],
    );
  }

  // ---- Text field (Enter to send on desktop, Shift+Enter for newline) -----
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
        style: const TextStyle(fontSize: 15, height: 1.4),
        decoration: const InputDecoration(
          hintText: 'Ask anything…',
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
              horizontal: Tokens.sp2, vertical: Tokens.sp2),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  // ---- Send / Stop with the context ring behind ---------------------------
  Widget _buildAction(
    AppState state, {
    required bool online,
    required bool busy,
    required bool canSend,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ring = (state.activeSession?.messages.length ?? 0) % 100 / 100;
    final tooltip = busy
        ? 'Stop'
        : !online
            ? 'Connect to bridge to send'
            : canSend
                ? 'Send'
                : 'Type a message';

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                value: ring,
                strokeWidth: 1.6,
                color: Tokens.accent,
                backgroundColor: Colors.transparent,
              ),
            ),
            Material(
              color: busy
                  ? Tokens.danger
                  : canSend
                      ? Tokens.accent
                      : scheme.surfaceContainerHighest,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: busy
                    ? () => state.interrupt()
                    : canSend
                        ? _submit
                        : null,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    busy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                    size: 17,
                    color: busy || canSend
                        ? Colors.white
                        : (dark
                            ? Tokens.darkTertiaryLabel
                            : Tokens.lightTertiaryLabel),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded mode pill — accent-filled when selected.
class _ModePill extends StatelessWidget {
  const _ModePill(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hairline = Theme.of(context).dividerTheme.color ?? scheme.outline;
    return Material(
      color: selected ? Tokens.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(Tokens.rFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.rFull),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Tokens.sp3, vertical: Tokens.sp1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.rFull),
            border: Border.all(
              color: selected ? Tokens.accent : hairline,
              width: selected ? 1.0 : 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? Tokens.accent
                  : (dark
                      ? Tokens.darkSecondaryLabel
                      : Tokens.lightSecondaryLabel),
            ),
          ),
        ),
      ),
    );
  }
}
