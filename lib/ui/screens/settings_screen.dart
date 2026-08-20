import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../services/openai_stream.dart';
import '../theme/kimi_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  late TextEditingController _keyCtrl;
  late TextEditingController _baseCtrl;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _urlCtrl = TextEditingController(text: s.bridgeUrl ?? '');
    _keyCtrl = TextEditingController(text: s.directApiKey);
    _baseCtrl = TextEditingController(text: s.directBaseUrl);
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
          Text('Model', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ProviderPresets.chatAnywhere.models.map((m) {
              final sel = state.selectedModel == m;
              return ChoiceChip(
                label: Text(m, style: TextStyle(fontSize: 12, color: sel ? KimiColors.lacquer : KimiColors.textPrimary)),
                selected: sel,
                selectedColor: KimiColors.accent,
                backgroundColor: KimiColors.surface,
                onSelected: (_) => state.setModel(m),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Swarm mode'),
            subtitle: const Text('Try multiple models until one responds'),
            value: state.swarmMode,
            activeColor: KimiColors.accent,
            onChanged: state.setSwarm,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('YOLO'),
            subtitle: const Text('Auto-approve tool calls when using bridge'),
            value: state.activeSession?.yolo ?? true,
            activeColor: KimiColors.thinking,
            onChanged: (_) => state.toggleYolo(),
          ),
          const SizedBox(height: 16),
          Text('API (direct)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(controller: _baseCtrl, decoration: const InputDecoration(labelText: 'Base URL')),
          const SizedBox(height: 8),
          TextField(controller: _keyCtrl, decoration: const InputDecoration(labelText: 'API Key'), obscureText: true),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              state.updateDirectProvider(baseUrl: _baseCtrl.text.trim(), apiKey: _keyCtrl.text.trim());
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API updated')));
            },
            child: const Text('Save API'),
          ),
          const SizedBox(height: 28),
          Text('VPS Bridge (optional)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: 'WebSocket URL')),
          const SizedBox(height: 8),
          Row(children: [
            ElevatedButton(
              onPressed: () async {
                state.bridgeUrl = _urlCtrl.text.trim();
                await state.connect();
              },
              child: const Text('Connect'),
            ),
            const SizedBox(width: 12),
            TextButton(onPressed: state.disconnect, child: const Text('Disconnect')),
          ]),
          const SizedBox(height: 8),
          Text(
            state.bridge.isConnected
                ? 'Bridge connected${state.latencyMs != null ? ' · ${state.latencyMs!.toStringAsFixed(0)} ms' : ''}'
                : state.connectionError ?? 'Bridge offline (chat still works via direct API)',
            style: TextStyle(
              fontSize: 12,
              color: state.bridge.isConnected ? KimiColors.success : KimiColors.textDim,
            ),
          ),
          const SizedBox(height: 28),
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Kimi Proxy · direct streaming + optional VPS bridge\n'
            'Swarm · YOLO · thinking stream · tool cards',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _baseCtrl.dispose();
    super.dispose();
  }
}
