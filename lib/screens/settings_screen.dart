import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/tokens.dart';

/// Settings — iOS-style grouped sections: Bridge, Appearance, About.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const _SettingsBody(),
    );
  }
}

// ---- Body (holds local controls that have no AppState setter yet) -----------

class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  static const List<String> _kTextSizes = [
    'small',
    'medium',
    'large',
    'xlarge'
  ];
  static const List<String> _kModels = ['kimi', 'kimi-latest', 'kimi-k2'];

  late final TextEditingController _url;
  late String _textSize;
  late String _model;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _url = TextEditingController(text: state.bridgeUrl);
    _textSize = state.fontSize;
    _model = state.defaultModel;
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _saveAndConnect() {
    final state = context.read<AppState>();
    final url = _url.text.trim();
    if (url.isEmpty) return;
    state.setBridgeUrl(url);
    state.connect();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        dark ? Tokens.darkSecondaryLabel : Tokens.lightSecondaryLabel;
    final online = state.connectionStatus == 'online';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Tokens.sp4, Tokens.sp2, Tokens.sp4, Tokens.sp8),
      children: [
        // ---- Bridge ----------------------------------------------------------
        const _SectionLabel('Bridge'),
        const SizedBox(height: Tokens.sp1),
        _SectionCard(
          children: [
            _bridgeField(scheme, secondary),
            const _Hairline(),
            _bridgeStatusRow(online, secondary),
          ],
        ),
        const SizedBox(height: Tokens.sp5),
        // ---- Appearance -------------------------------------------------------
        const _SectionLabel('Appearance'),
        const SizedBox(height: Tokens.sp1),
        _SectionCard(
          children: [
            _row(
              'Theme',
              _Pills<String>(
                values: const ['dark', 'light'],
                label: (v) => v == 'dark' ? 'Dark' : 'Light',
                selected: state.theme,
                onChanged: state.setTheme,
              ),
            ),
            const _Hairline(),
            _row(
              'Text size',
              _Pills<String>(
                values: _kTextSizes,
                label: (String v) => switch (v) {
                  'small' => 'S',
                  'large' => 'L',
                  'xlarge' => 'XL',
                  _ => 'M',
                },
                selected: _textSize,
                onChanged: (v) => setState(() => _textSize = v),
              ),
            ),
            const _Hairline(),
            _row('Default model', _modelDropdown(state, scheme)),
          ],
        ),
        const SizedBox(height: Tokens.sp5),
        // ---- About -------------------------------------------------------------
        const _SectionLabel('About'),
        const SizedBox(height: Tokens.sp1),
        _SectionCard(
          children: [
            _row(
              'Version',
              Text('Kimi Proxy 2.0.0',
                  style: TextStyle(fontSize: 15, color: secondary)),
            ),
          ],
        ),
      ],
    );
  }

  // ---- Rows -----------------------------------------------------------------
  Widget _row(String title, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.sp4, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: Tokens.sp3),
          trailing,
        ],
      ),
    );
  }

  Widget _bridgeField(ColorScheme scheme, Color secondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Tokens.sp4, Tokens.sp3, Tokens.sp4, Tokens.sp3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WebSocket URL',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: secondary),
          ),
          const SizedBox(height: Tokens.sp1),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'ws://127.0.0.1:8765',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bridgeStatusRow(bool online, Color secondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Tokens.sp4, Tokens.sp2, Tokens.sp4, Tokens.sp4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              online ? 'Connected' : 'Offline',
              style: TextStyle(fontSize: 13, color: secondary),
            ),
          ),
          FilledButton.icon(
            onPressed: _saveAndConnect,
            icon: const Icon(Icons.link_rounded, size: 15),
            label: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  Widget _modelDropdown(AppState state, ColorScheme scheme) {
    return DropdownButton<String>(
      value: _model,
      isDense: true,
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(Tokens.rMd),
      dropdownColor: scheme.surface,
      style: TextStyle(fontSize: 14, color: scheme.onSurface),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
      onChanged: (v) {
        if (v == null) return;
        setState(() => _model = v);
        state.config(model: v);
      },
      items: [
        for (final m in _kModels)
          DropdownMenuItem(
              value: m, child: Text(m, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}

// ---- Grouped-section helpers -------------------------------------------------

/// Small uppercase-ish section header above a card group.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? Tokens.darkSecondaryLabel : Tokens.lightSecondaryLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.sp2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}

/// iOS grouped card — surface fill, hairline border, clipped rows.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hairline = Theme.of(context).dividerTheme.color ?? scheme.outline;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Tokens.rCard),
        border: Border.all(color: hairline, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Inset hairline separator between grouped rows (iOS style).
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hairline = Theme.of(context).dividerTheme.color ?? scheme.outline;
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: Tokens.sp4,
      endIndent: Tokens.sp4,
      color: hairline,
    );
  }
}

/// Compact segmented control — iOS-like pills on a filled track.
class _Pills<T> extends StatelessWidget {
  const _Pills({
    required this.values,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T) label;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary =
        dark ? Tokens.darkSecondaryLabel : Tokens.lightSecondaryLabel;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Tokens.rFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            _pill(scheme, secondary, values[i]),
          ],
        ],
      ),
    );
  }

  Widget _pill(ColorScheme scheme, Color secondary, T value) {
    final isSelected = value == selected;
    return Material(
      color: isSelected ? scheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(Tokens.rFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.rFull),
        onTap: () => onChanged(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Tokens.sp3, vertical: Tokens.sp1 + 1),
          child: Text(
            label(value),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? scheme.onSurface : secondary,
            ),
          ),
        ),
      ),
    );
  }
}
