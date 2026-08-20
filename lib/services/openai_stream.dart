import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Direct OpenAI-compatible streaming (bypasses broken local 8789 proxy).
class OpenAIStreamService {
  final String baseUrl;
  final String apiKey;

  OpenAIStreamService({
    required this.baseUrl,
    required this.apiKey,
  });

  /// Stream deltas: type = content | thinking | error | done
  Stream<Map<String, String>> chat({
    required String model,
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int? maxTokens,
  }) async* {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}/chat/completions');
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': true,
      'temperature': temperature,
    };
    if (maxTokens != null) body['max_tokens'] = maxTokens;

    final req = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode(body);

    final client = http.Client();
    try {
      final res = await client.send(req).timeout(const Duration(seconds: 60));
      if (res.statusCode >= 400) {
        final err = await res.stream.bytesToString();
        yield {'type': 'error', 'text': 'HTTP ${res.statusCode}: ${err.length > 200 ? err.substring(0, 200) : err}'};
        return;
      }

      var buffer = '';
      await for (final chunk in res.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
          final data = trimmed.substring(5).trim();
          if (data == '[DONE]') {
            yield {'type': 'done'};
            return;
          }
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final delta = json['choices']?[0]?['delta'] as Map<String, dynamic>? ?? {};
            final content = delta['content'] as String?;
            final reasoning = (delta['reasoning_content'] ?? delta['reasoning']) as String?;
            if (reasoning != null && reasoning.isNotEmpty) {
              yield {'type': 'thinking', 'text': reasoning};
            }
            if (content != null && content.isNotEmpty) {
              yield {'type': 'content', 'text': content};
            }
          } catch (_) {}
        }
      }
      yield {'type': 'done'};
    } on TimeoutException {
      yield {'type': 'error', 'text': 'Request timed out'};
    } catch (e) {
      yield {'type': 'error', 'text': e.toString()};
    } finally {
      client.close();
    }
  }

  /// Swarm: race several models, yield first successful stream.
  Stream<Map<String, String>> swarm({
    required List<String> models,
    required List<Map<String, String>> messages,
  }) async* {
    if (models.isEmpty) {
      yield {'type': 'error', 'text': 'No models in swarm'};
      return;
    }
    // Sequential fallback (true parallel race is heavier on mobile)
    for (final model in models) {
      yield {'type': 'status', 'text': 'Trying $model…'};
      var gotContent = false;
      await for (final ev in chat(model: model, messages: messages)) {
        if (ev['type'] == 'error') {
          yield {'type': 'status', 'text': '$model failed, next…'};
          break;
        }
        if (ev['type'] == 'content' || ev['type'] == 'thinking') {
          gotContent = true;
          yield {...ev, 'model': model};
        }
        if (ev['type'] == 'done') {
          if (gotContent) {
            yield {'type': 'done', 'model': model};
            return;
          }
          break;
        }
      }
    }
    yield {'type': 'error', 'text': 'All swarm models failed'};
  }
}

/// Known working provider presets
class ProviderPresets {
  static const chatAnywhere = (
    baseUrl: 'https://api.chatanywhere.tech/v1',
    // User-provided key already in use on VPS
    apiKey: 'sk-sAMc6LYsb7Ui5VkBVq3hpU35IvyH61UGyTYuiEBarKCjCSgL',
    models: [
      'gpt-4.1-nano',
      'gpt-4.1-mini',
      'gpt-4o-mini',
      'deepseek-v3',
      'gpt-4o',
    ],
  );
}
