/**
 * Kimi Proxy Bridge v2 — multi-provider failover (no single 8789 dependency)
 * Port 9876 WebSocket + HTTP health
 */
const http = require('http');
const { WebSocketServer } = require('ws');
const { randomUUID } = require('crypto');

const PORT = process.env.KIMI_BRIDGE_PORT || 9876;

// Provider chain: try in order until one works
const PROVIDERS = [
  {
    name: 'chatanywhere',
    base: 'https://api.chatanywhere.tech/v1',
    key: process.env.CHATANYWHERE_KEY || 'sk-sAMc6LYsb7Ui5VkBVq3hpU35IvyH61UGyTYuiEBarKCjCSgL',
    models: { default: 'gpt-4.1-nano', flash: 'gpt-4.1-nano', mini: 'gpt-4.1-mini', full: 'gpt-4o' },
  },
  {
    name: 'local-8789',
    base: 'http://127.0.0.1:8789/v1',
    key: process.env.OPENAI_KEY || 'ai-proxy-local',
    models: { default: 'ai-proxy/deepseek-v4-flash' },
  },
  {
    name: 'local-8765',
    base: 'http://127.0.0.1:8765/v1',
    key: process.env.ZAI_KEY || process.env.PAAS_API_KEY || '',
    models: { default: 'glm-4-flash' },
  },
];

const sessions = new Map();

function log(...a) { console.log(new Date().toISOString(), ...a); }

function broadcast(sessionId, event) {
  const s = sessions.get(sessionId);
  if (!s) return;
  const payload = JSON.stringify({ ...event, sessionId });
  for (const ws of s.clients) {
    if (ws.readyState === 1) ws.send(payload);
  }
}

function createSession({ name, workDir, model } = {}) {
  const id = randomUUID();
  const s = {
    id,
    name: name || `Session ${sessions.size + 1}`,
    workDir: workDir || process.cwd(),
    model: model || 'gpt-4.1-nano',
    yolo: true,
    planMode: false,
    thinkingEnabled: true,
    history: [],
    clients: new Set(),
    status: 'idle',
  };
  sessions.set(id, s);
  return s;
}

function resolveModel(provider, modelId) {
  if (!modelId) return provider.models.default;
  // strip ai-proxy/ chatanywhere/ prefixes for external APIs
  const bare = modelId.replace(/^(ai-proxy|chatanywhere|nousresearch)\//, '');
  if (provider.name === 'chatanywhere') {
    if (bare.includes('nano')) return 'gpt-4.1-nano';
    if (bare.includes('mini')) return 'gpt-4.1-mini';
    if (bare.includes('deepseek')) return 'deepseek-v3';
    if (bare.includes('gpt-4o')) return 'gpt-4o';
    return bare || provider.models.default;
  }
  return modelId;
}

async function fetchChat(provider, body) {
  const url = `${provider.base}/chat/completions`;
  const headers = { 'Content-Type': 'application/json' };
  if (provider.key) headers.Authorization = `Bearer ${provider.key}`;
  const res = await fetch(url, { method: 'POST', headers, body: JSON.stringify(body) });
  return res;
}

async function streamChatCompletion(session, userText) {
  const messages = [...session.history, { role: 'user', content: userText }];
  broadcast(session.id, { type: 'status', status: 'streaming' });
  session.status = 'streaming';

  let lastError = null;
  for (const provider of PROVIDERS) {
    if (!provider.key && provider.name !== 'local-8789') continue;
    const model = resolveModel(provider, session.model);
    const body = { model, messages, stream: true, temperature: 0.7 };
    log('try', provider.name, model);
    broadcast(session.id, { type: 'content.delta', delta: '' }); // keep stream alive
    try {
      const res = await fetchChat(provider, body);
      if (res.status === 503 || res.status === 429) {
        const t = await res.text().catch(() => '');
        lastError = `${provider.name} ${res.status}: ${t.slice(0, 120)}`;
        log('busy', lastError);
        continue;
      }
      if (!res.ok) {
        const t = await res.text().catch(() => '');
        lastError = `${provider.name} HTTP ${res.status}: ${t.slice(0, 150)}`;
        log('fail', lastError);
        continue;
      }

      // Stream success
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      let fullContent = '';
      let fullThinking = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';
        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed.startsWith('data:')) continue;
          const data = trimmed.slice(5).trim();
          if (data === '[DONE]') continue;
          let parsed;
          try { parsed = JSON.parse(data); } catch { continue; }
          const delta = parsed.choices?.[0]?.delta || {};
          const reasoning = delta.reasoning_content || delta.reasoning;
          if (reasoning) {
            fullThinking += reasoning;
            broadcast(session.id, { type: 'thinking.delta', delta: reasoning });
          }
          if (delta.content) {
            fullContent += delta.content;
            broadcast(session.id, { type: 'content.delta', delta: delta.content });
          }
        }
      }

      session.history.push({ role: 'user', content: userText });
      if (fullContent || fullThinking) {
        session.history.push({
          role: 'assistant',
          content: fullContent,
          ...(fullThinking ? { reasoning_content: fullThinking } : {}),
        });
      }
      session.status = 'idle';
      broadcast(session.id, { type: 'turn.complete', provider: provider.name, model });
      return;
    } catch (e) {
      lastError = `${provider.name}: ${e.message}`;
      log('error', lastError);
    }
  }

  broadcast(session.id, {
    type: 'error',
    message: lastError || 'All providers failed',
  });
  session.status = 'error';
  broadcast(session.id, { type: 'turn.complete' });
}

function handleMessage(ws, raw) {
  let msg;
  try { msg = JSON.parse(raw); } catch {
    ws.send(JSON.stringify({ type: 'error', message: 'invalid JSON' }));
    return;
  }
  const type = msg.type;

  if (type === 'ping') {
    ws.send(JSON.stringify({ type: 'pong', ts: msg.ts || Date.now() }));
    return;
  }
  if (type === 'session.create') {
    const s = createSession({ name: msg.name, workDir: msg.workDir, model: msg.model });
    s.clients.add(ws);
    ws._sessionId = s.id;
    ws.send(JSON.stringify({
      type: 'session.created',
      session: {
        id: s.id, name: s.name, workDir: s.workDir, model: s.model,
        yolo: s.yolo, planMode: s.planMode, thinkingEnabled: s.thinkingEnabled,
        status: s.status, createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(), messageCount: 0, pinned: false,
      },
    }));
    return;
  }
  if (type === 'session.list') {
    const list = [...sessions.values()].map((s) => ({
      id: s.id, name: s.name, workDir: s.workDir, model: s.model,
      yolo: s.yolo, planMode: s.planMode, thinkingEnabled: s.thinkingEnabled,
      status: s.status, messageCount: s.history.length, pinned: false,
      createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
    }));
    ws.send(JSON.stringify({ type: 'session.list', sessions: list }));
    return;
  }
  if (type === 'prompt') {
    const sessionId = msg.sessionId || ws._sessionId;
    const s = sessions.get(sessionId);
    if (!s) {
      ws.send(JSON.stringify({ type: 'error', message: 'session not found' }));
      return;
    }
    s.clients.add(ws);
    streamChatCompletion(s, msg.content || '');
    return;
  }
  if (type === 'config') {
    const s = sessions.get(msg.sessionId);
    if (!s) return;
    if (typeof msg.yolo === 'boolean') s.yolo = msg.yolo;
    if (typeof msg.planMode === 'boolean') s.planMode = msg.planMode;
    if (typeof msg.model === 'string') s.model = msg.model;
    broadcast(s.id, { type: 'status', status: s.status, yolo: s.yolo, planMode: s.planMode, model: s.model });
    return;
  }
  if (type === 'interrupt') {
    const s = sessions.get(msg.sessionId);
    if (s) { s.status = 'idle'; broadcast(s.id, { type: 'turn.complete' }); }
  }
}

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, sessions: sessions.size, port: PORT, providers: PROVIDERS.map(p => p.name) }));
    return;
  }
  res.writeHead(404); res.end();
});

const wss = new WebSocketServer({ server });
wss.on('connection', (ws) => {
  log('client connected');
  ws.send(JSON.stringify({ type: 'connected' }));
  ws.on('message', (data) => {
    try { handleMessage(ws, data.toString()); }
    catch (e) { ws.send(JSON.stringify({ type: 'error', message: e.message })); }
  });
  ws.on('close', () => {
    for (const s of sessions.values()) s.clients.delete(ws);
  });
});

server.listen(PORT, '0.0.0.0', () => {
  log(`Bridge v2 on 0.0.0.0:${PORT}`);
  log('Providers:', PROVIDERS.map(p => p.name).join(', '));
});
