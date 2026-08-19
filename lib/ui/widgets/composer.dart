import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/kimi_theme.dart';

class Composer extends StatefulWidget {
  final bool enabled;
  final bool isStreaming;
  final ValueChanged<String> onSend;
  final VoidCallback onInterrupt;

  const Composer({
    super.key,
    required this.enabled,
    required this.isStreaming,
    required this.onSend,
    required this.onInterrupt,
  });

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: KimiColors.hairline)),
        color: KimiColors.lacquer,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _submit();
                }
              },
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: widget.enabled && !widget.isStreaming,
                maxLines: 6,
                minLines: 1,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: widget.isStreaming
                      ? 'Kimi is working…'
                      : 'Message Kimi…',
                  suffixIcon: widget.isStreaming
                      ? IconButton(
                          icon: const Icon(Icons.stop_circle_outlined),
                          color: KimiColors.danger,
                          onPressed: widget.onInterrupt,
                        )
                      : null,
                ),
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (!widget.isStreaming)
            IconButton.filled(
              onPressed: widget.enabled ? _submit : null,
              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: KimiColors.accent,
                foregroundColor: KimiColors.lacquer,
                disabledBackgroundColor: KimiColors.surfaceRaised,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(44, 44),
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
