import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../services/bridge_service.dart';
import '../theme/kimi_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _urlCtrl = TextEditingController(text: state.bridgeUrl ?? '');
  }

  Future<void> _connect() async {
    final state = context.read<AppState>();
    setState(() => _busy = true);
    state.bridgeUrl = _urlCtrl.text.trim();
    try {
      await state.connect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.bridge.isConnected ? 'Connected' : 'Failed'),
            backgroundColor: state.bridge.isConnected
                ? KimiColors.success
                : KimiColors.danger,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection failed — see status below'),
            backgroundColor: KimiColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final url = _urlCtrl.text.trim();
    final mixed = BridgeService.isMixedContentBlocked(
      url.isEmpty ? (state.bridgeUrl ?? '') : url,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (mixed) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: KimiColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: KimiColors.danger.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: KimiColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Mixed content blocked',
                        style: TextStyle(
                          color: KimiColors.danger,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This page is HTTPS (GitHub Pages). Browsers block insecure ws:// connections.\n\n'
                    'We will host the UI on the VPS over HTTP or enable wss:// with TLS.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: KimiColors.textPrimary,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text('Bridge', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'WebSocket URL',
              hintText: 'ws://your-vps:9876',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: _busy ? null : _connect,
                child: Text(_busy ? 'Connecting…' : 'Connect'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: state.disconnect,
                child: const Text('Disconnect'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            state.bridge.isConnected
                ? 'Connected${state.latencyMs != null ? ' · ${state.latencyMs!.toStringAsFixed(0)} ms' : ''}'
                : state.connecting || _busy
                    ? 'Connecting…'
                    : state.connectionError ?? 'Disconnected',
            style: TextStyle(
              color: state.bridge.isConnected
                  ? KimiColors.success
                  : (state.connectionError != null ? KimiColors.danger : KimiColors.textDim),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (state.connectionError != null && !state.bridge.isConnected) ...[
            const SizedBox(height: 8),
            SelectableText(
              state.connectionError!,
              style: KimiTheme.monoSmall.copyWith(color: KimiColors.danger),
            ),
          ],
          const SizedBox(height: 28),
          Text('Quick fix', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '1. Bridge is live at ws://85.121.148.62:9876.\n'
            '2. Phone on GitHub Pages cannot use ws:// (HTTPS mixed content).\n'
            '3. Next: host web UI on VPS HTTP or add wss:// TLS.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: 'ws://85.121.148.62:9876'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bridge URL copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy bridge URL'),
          ),
          const SizedBox(height: 32),
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Kimi Proxy — ultra-fast remote client for Kimi Code CLI.\n'
            'Lacquer design · streaming thinking · tool cards · multi-session.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'VPS bridge: ws://85.121.148.62:9876\n'
            'Repo: github.com/darrellojie350-wq/kimi-proxy',
            style: KimiTheme.monoSmall,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }
}
