/**
 * Kimi Proxy Bridge v1
 * WebSocket server that drives Kimi Code CLI / OpenAI-compatible backends
 * and streams thinking + tool calls + content to the Flutter client.
 *
 * Port: 8766 (8765 is already used by existing zai-service bridge)
 */
const http = require('http');
const { WebSocketServer } = require('ws');
const { spawn } = require('child_process');
const { randomUUID } = require('crypto');
const fs = require('fs');
const path = require('path');

const PORT = process.env.KIMI_BRIDGE_PORT || 8766;
const KIMI_BIN = process.env.KIMI_BIN || 'C:\\Users\\Admin\\.kimi-code\\bin\\kimi.exe';
const OPENAI_BASE = process.env.OPENAI_BASE || 'http://127.0.0.1:8789/v1';
const OPENAI_KEY = process.env.OPENAI_KEY || 'ai-proxy-local';
const DEFAULT_MODEL = process.env.DEFAULT_MODEL || 'ai-proxy/deepseek-v4-flash';

const sessions = new Map(); // id -> { id, name, workDir, model, yolo, planMode, history, clients }

function log(...args) {
  console.log(new Date().toISOString(), ...args);
}

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
    model: model || DEFAULT_MODEL,
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

async function streamChatCompletion(session, userText) {
  const messages = [
    ...session.history,
    { role: 'user', content: userText },
  ];

  broadcast(session.id, { type: 'status', status: 'streaming' });
  session.status = 'streaming';

  const body = {
    model: session.model,
    messages,
    stream: true,
    temperature: 0.7,
  };

  // Try to enable thinking if backend supports it
  body.thinking = { type: 'enabled' };

  let res;
  try {
    res = await fetch(`${OPENAI_BASE}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${OPENAI_KEY}`,
      },
      body: JSON.stringify(body),
    });
  } catch (e) {
    broadcast(session.id, { type: 'error', message: `Upstream error: ${e.message}` });
    session.status = 'error';
    return;
  }

  if (!res.ok) {
    const errText = await res.text().catch(() => '');
    if (res.status === 503) {
      broadcast(session.id, { type: 'content.delta', delta: '\n[upstream busy — retrying in 3s…]\n' });
      await new Promise(r => setTimeout(r, 3000));
      try {
        res = await fetch(`${OPENAI_BASE}/chat/completions`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${OPENAI_KEY}` },
          body: JSON.stringify(body),
        });
      } catch (e2) {
        broadcast(session.id, { type: 'error', message: `Retry failed: ${e2.message}` });
        session.status = 'error';
        return;
      }
      if (!res.ok) {
        const err2 = await res.text().catch(() => '');
        broadcast(session.id, { type: 'error', message: `HTTP ${res.status}: ${err2.slice(0, 300)}` });
        session.status = 'error';
        return;
      }
    } else {
      broadcast(session.id, { type: 'error', message: `HTTP ${res.status}: ${errText.slice(0, 300)}` });
      session.status = 'error';
      return;
    }
  }

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let fullContent = '';
  let fullThinking = '';
  let currentToolCalls = {};

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || !trimmed.startsWith('data:')) continue;
        const data = trimmed.slice(5).trim();
        if (data === '[DONE]') continue;
        let parsed;
        try {
          parsed = JSON.parse(data);
        } catch {
          continue;
        }
        const delta = parsed.choices?.[0]?.delta || {};
        const reasoning = delta.reasoning_content || delta.reasoning || null;
        if (reasoning) {
          fullThinking += reasoning;
          broadcast(session.id, { type: 'thinking.delta', delta: reasoning });
        }
        if (delta.content) {
          fullContent += delta.content;
          broadcast(session.id, { type: 'content.delta', delta: delta.content });
        }
        // Tool calls (OpenAI style)
        if (delta.tool_calls) {
          for (const tc of delta.tool_calls) {
            const idx = tc.index ?? 0;
            if (!currentToolCalls[idx]) {
              currentToolCalls[idx] = {
                id: tc.id || randomUUID(),
                name: tc.function?.name || '',
                arguments: '',
              };
              broadcast(session.id, {
                type: 'tool.call',
                toolCallId: currentToolCalls[idx].id,
                name: currentToolCalls[idx].name,
                arguments: {},
              });
            }
            if (tc.function?.name) currentToolCalls[idx].name = tc.function.name;
            if (tc.function?.arguments) {
              currentToolCalls[idx].arguments += tc.function.arguments;
            }
          }
        }
      }
    }
  } catch (e) {
    broadcast(session.id, { type: 'error', message: e.message });
  }

  // Finalize tool argument JSON
  for (const tc of Object.values(currentToolCalls)) {
    let args = {};
    try {
      args = JSON.parse(tc.arguments || '{}');
    } catch {
      args = { raw: tc.arguments };
    }
    broadcast(session.id, {
      type: 'tool.status',
      toolCallId: tc.id,
      status: 'success',
    });
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
  broadcast(session.id, { type: 'turn.complete' });
}

function handleMessage(ws, raw) {
  let msg;
  try {
    msg = JSON.parse(raw);
  } catch {
    ws.send(JSON.stringify({ type: 'error', message: 'invalid JSON' }));
    return;
  }

  const type = msg.type;

  if (type === 'ping') {
    ws.send(JSON.stringify({ type: 'pong', ts: msg.ts || Date.now() }));
    return;
  }

  if (type === 'session.create') {
    const s = createSession({
      name: msg.name,
      workDir: msg.workDir,
      model: msg.model,
    });
    s.clients.add(ws);
    ws._sessionId = s.id;
    ws.send(JSON.stringify({
      type: 'session.created',
      session: {
        id: s.id,
        name: s.name,
        workDir: s.workDir,
        model: s.model,
        yolo: s.yolo,
        planMode: s.planMode,
        thinkingEnabled: s.thinkingEnabled,
        status: s.status,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        messageCount: 0,
        pinned: false,
      },
    }));
    return;
  }

  if (type === 'session.list') {
    const list = [...sessions.values()].map((s) => ({
      id: s.id,
      name: s.name,
      workDir: s.workDir,
      model: s.model,
      yolo: s.yolo,
      planMode: s.planMode,
      thinkingEnabled: s.thinkingEnabled,
      status: s.status,
      messageCount: s.history.length,
      pinned: false,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
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
    // Soft interrupt — next version can abort fetch
    const s = sessions.get(msg.sessionId);
    if (s) {
      s.status = 'idle';
      broadcast(s.id, { type: 'turn.complete' });
    }
    return;
  }

  if (type === 'tool.approve' || type === 'tool.deny') {
    // Placeholder for YOLO-off flow
    return;
  }
}

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, sessions: sessions.size, port: PORT }));
    return;
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  log('client connected');
  ws.send(JSON.stringify({ type: 'connected' }));

  ws.on('message', (data) => {
    try {
      handleMessage(ws, data.toString());
    } catch (e) {
      log('handle error', e);
      ws.send(JSON.stringify({ type: 'error', message: e.message }));
    }
  });

  ws.on('close', () => {
    log('client disconnected');
    for (const s of sessions.values()) s.clients.delete(ws);
  });
});

server.listen(PORT, '0.0.0.0', () => {
  log(`Kimi Proxy Bridge listening on 0.0.0.0:${PORT}`);
  log(`Upstream: ${OPENAI_BASE} model=${DEFAULT_MODEL}`);
});
