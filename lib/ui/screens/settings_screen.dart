import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../theme/kimi_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _urlCtrl = TextEditingController(text: state.bridgeUrl ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

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
          Text('Bridge', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'WebSocket URL',
              hintText: 'ws://your-vps:9876',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  state.bridgeUrl = _urlCtrl.text.trim();
                  state.connect();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Connecting…')),
                  );
                },
                child: const Text('Connect'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: state.disconnect,
                child: const Text('Disconnect'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.bridge.isConnected
                ? 'Connected${state.latencyMs != null ? ' · ${state.latencyMs!.toStringAsFixed(0)} ms' : ''}'
                : state.connecting
                    ? 'Connecting…'
                    : state.connectionError ?? 'Disconnected',
            style: TextStyle(
              color: state.bridge.isConnected ? KimiColors.success : KimiColors.textDim,
              fontSize: 13,
            ),
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
