import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/kimi_theme.dart';

class Composer extends StatefulWidget {
  final bool connected;
  final bool hasSession;
  final bool isStreaming;
  final ValueChanged<String> onSend;
  final VoidCallback onInterrupt;
  final VoidCallback? onNeedConnect;
  final VoidCallback? onNeedSession;

  const Composer({
    super.key,
    required this.connected,
    required this.hasSession,
    required this.isStreaming,
    required this.onSend,
    required this.onInterrupt,
    this.onNeedConnect,
    this.onNeedSession,
  });

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  bool get _canType => !widget.isStreaming;
  bool get _canSend =>
      widget.connected && widget.hasSession && !widget.isStreaming;

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (!widget.connected) {
      widget.onNeedConnect?.call();
      _showHint('Connect to the bridge first (Settings ⚙)');
      return;
    }
    if (!widget.hasSession) {
      widget.onNeedSession?.call();
      // allow send after session auto-created by parent
      widget.onSend(text);
      _controller.clear();
      _focus.requestFocus();
      return;
    }
    if (widget.isStreaming) return;

    widget.onSend(text);
    _controller.clear();
    _focus.requestFocus();
  }

  void _showHint(String msg) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String hint;
    if (widget.isStreaming) {
      hint = 'Kimi is working…';
    } else if (!widget.connected) {
      hint = 'Connect bridge to chat…';
    } else if (!widget.hasSession) {
      hint = 'Message Kimi (session will start)…';
    } else {
      hint = 'Message Kimi…';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: KimiColors.hairline)),
        color: KimiColors.lacquer,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              // Always allow tap + keyboard — never freeze the field
              enabled: true,
              readOnly: widget.isStreaming,
              maxLines: 6,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              onTap: () {
                if (!widget.connected) {
                  widget.onNeedConnect?.call();
                }
              },
              style: Theme.of(context).textTheme.bodyLarge,
              cursorColor: KimiColors.accent,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: KimiColors.textDim,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: KimiColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: KimiColors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: KimiColors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: KimiColors.accent, width: 1.5),
                ),
                suffixIcon: widget.isStreaming
                    ? IconButton(
                        icon: const Icon(Icons.stop_circle_outlined),
                        color: KimiColors.danger,
                        onPressed: widget.onInterrupt,
                        tooltip: 'Stop',
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (widget.isStreaming)
            IconButton.filled(
              onPressed: widget.onInterrupt,
              icon: const Icon(Icons.stop_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: KimiColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(48, 48),
              ),
            )
          else
            IconButton.filled(
              onPressed: _submit,
              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: _canSend || (!widget.connected || !widget.hasSession)
                    ? KimiColors.accent
                    : KimiColors.surfaceRaised,
                foregroundColor: KimiColors.lacquer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(48, 48),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }
}
