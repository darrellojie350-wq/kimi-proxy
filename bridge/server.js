/**
 * Kimi Proxy Bridge — WebSocket front-end for Kimi Code CLI on the VPS.
 * Protocol matches Flutter BridgeService.
 *
 * Run: node server.js
 * Default port: 8765
 */

const http = require('http');
const { WebSocketServer } = require('ws');
const { spawn } = require('child_process');
const { randomUUID } = require('crypto');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8765;
const KIMI_BIN = process.env.KIMI_BIN || 'C:\\Users\\Admin\\.kimi-code\\bin\\kimi.exe';
const WORK_ROOT = process.env.KIMI_WORK_ROOT || 'C:\\Users\\Admin\\kimi-proxy-sessions';

if (!fs.existsSync(WORK_ROOT)) {
  fs.mkdirSync(WORK_ROOT, { recursive: true });
}

/** @type {Map<string, Session>} */
const sessions = new Map();

class Session {
  constructor(id, name, workDir) {
    this.id = id;
    this.name = name || `Session ${id.slice(0, 6)}`;
    this.workDir = workDir || path.join(WORK_ROOT, id);
    this.status = 'idle';
    this.yolo = true;
    this.planMode = false;
    this.thinkingEnabled = true;
    this.model = null;
    this.createdAt = new Date().toISOString();
    this.updatedAt = this.createdAt;
    this.messageCount = 0;
    this.proc = null;
    if (!fs.existsSync(this.workDir)) fs.mkdirSync(this.workDir, { recursive: true });
  }

  toJSON() {
    return {
      id: this.id,
      name: this.name,
      workDir: this.workDir,
      status: this.status,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt,
      messageCount: this.messageCount,
      pinned: false,
      model: this.model,
      yolo: this.yolo,
      planMode: this.planMode,
      thinkingEnabled: this.thinkingEnabled,
    };
  }
}

function send(ws, obj) {
  if (ws.readyState === 1) ws.send(JSON.stringify(obj));
}

function broadcast(obj) {
  // single-client for now; extend later
}

function runKimiPrompt(session, prompt, ws) {
  return new Promise((resolve) => {
    session.status = 'streaming';
    session.updatedAt = new Date().toISOString();
    send(ws, { type: 'status', sessionId: session.id, status: 'streaming' });

    const args = [
      '-p', prompt,
      '--output-format', 'stream-json',
      '-y', // yolo for bridge; app still controls approval UX later
    ];
    if (session.model) args.push('-m', session.model);
    if (session.planMode) args.push('--plan');

    const proc = spawn(KIMI_BIN, args, {
      cwd: session.workDir,
      env: { ...process.env },
      windowsHide: true,
    });
    session.proc = proc;

    let buffer = '';
    const flushLine = (line) => {
      line = line.trim();
      if (!line) return;
      try {
        const evt = JSON.parse(line);
        handleStreamEvent(session, evt, ws);
      } catch {
        // plain text fallback
        if (line) {
          send(ws, { type: 'content.delta', sessionId: session.id, delta: line + '\n' });
        }
      }
    };

    proc.stdout.on('data', (chunk) => {
      buffer += chunk.toString();
      const lines = buffer.split(/\r?\n/);
      buffer = lines.pop() || '';
      for (const line of lines) flushLine(line);
    });

    proc.stderr.on('data', (chunk) => {
      const t = chunk.toString();
      // kimi sometimes logs to stderr
      if (t.includes('error') || t.includes('Error')) {
        send(ws, { type: 'content.delta', sessionId: session.id, delta: t });
      }
    });

    proc.on('close', (code) => {
      if (buffer.trim()) flushLine(buffer);
      session.status = 'idle';
      session.proc = null;
      session.messageCount += 1;
      session.updatedAt = new Date().toISOString();
      send(ws, { type: 'turn.complete', sessionId: session.id, code });
      send(ws, { type: 'status', sessionId: session.id, status: 'idle' });
      resolve(code);
    });

    proc.on('error', (err) => {
      session.status = 'error';
      session.proc = null;
      send(ws, { type: 'error', sessionId: session.id, message: err.message });
      send(ws, { type: 'turn.complete', sessionId: session.id });
      resolve(1);
    });
  });
}

function handleStreamEvent(session, evt, ws) {
  // Flexible mapping — stream-json shape may vary by kimi version
  const type = evt.type || evt.event || '';
  const sid = session.id;

  if (type.includes('thinking') || evt.reasoning_content || evt.thinking) {
    const delta = evt.delta || evt.reasoning_content || evt.thinking || evt.text || '';
    if (delta) send(ws, { type: 'thinking.delta', sessionId: sid, delta });
    session.status = 'thinking';
    return;
  }

  if (type.includes('tool') || evt.tool_call || evt.name) {
    const toolCallId = evt.id || evt.tool_call_id || randomUUID();
    const name = evt.name || evt.tool || 'tool';
    const args = evt.arguments || evt.args || {};
    send(ws, {
      type: 'tool.call',
      sessionId: sid,
      toolCallId,
      name,
      arguments: typeof args === 'string' ? { raw: args } : args,
    });
    session.status = 'toolRunning';
    return;
  }

  if (type.includes('tool_result') || type.includes('tool.output') || evt.output) {
    send(ws, {
      type: 'tool.output',
      sessionId: sid,
      toolCallId: evt.tool_call_id || evt.id || '',
      output: evt.output || evt.content || evt.result || '',
    });
    send(ws, {
      type: 'tool.status',
      sessionId: sid,
      toolCallId: evt.tool_call_id || evt.id || '',
      status: evt.status || 'success',
    });
    return;
  }

  // content / message deltas
  const delta = evt.delta || evt.content || evt.text || evt.message || '';
  if (delta && typeof delta === 'string') {
    send(ws, { type: 'content.delta', sessionId: sid, delta });
    session.status = 'streaming';
  }
}

function interruptSession(session) {
  if (session.proc) {
    try {
      session.proc.kill('SIGTERM');
    } catch (_) {}
    session.proc = null;
  }
  session.status = 'idle';
}

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, sessions: sessions.size }));
    return;
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  console.log('[bridge] client connected');
  send(ws, { type: 'connected' });

  // send existing sessions
  send(ws, {
    type: 'session.list',
    sessions: Array.from(sessions.values()).map((s) => s.toJSON()),
  });

  ws.on('message', async (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return;
    }

    const t = msg.type;

    if (t === 'ping') {
      send(ws, { type: 'pong', ts: msg.ts || Date.now() });
      return;
    }

    if (t === 'session.create') {
      const id = randomUUID();
      const s = new Session(id, msg.name, msg.workDir);
      if (msg.model) s.model = msg.model;
      sessions.set(id, s);
      send(ws, { type: 'session.created', session: s.toJSON() });
      return;
    }

    if (t === 'session.list') {
      send(ws, {
        type: 'session.list',
        sessions: Array.from(sessions.values()).map((s) => s.toJSON()),
      });
      return;
    }

    if (t === 'prompt') {
      const s = sessions.get(msg.sessionId);
      if (!s) {
        send(ws, { type: 'error', message: 'session not found' });
        return;
      }
      const prompt = msg.content || '';
      if (!prompt.trim()) return;
      // fire and forget async
      runKimiPrompt(s, prompt, ws);
      return;
    }

    if (t === 'interrupt') {
      const s = sessions.get(msg.sessionId);
      if (s) {
        interruptSession(s);
        send(ws, { type: 'turn.complete', sessionId: s.id });
        send(ws, { type: 'status', sessionId: s.id, status: 'idle' });
      }
      return;
    }

    if (t === 'config') {
      const s = sessions.get(msg.sessionId);
      if (!s) return;
      if (typeof msg.yolo === 'boolean') s.yolo = msg.yolo;
      if (typeof msg.planMode === 'boolean') s.planMode = msg.planMode;
      if (msg.model) s.model = msg.model;
      send(ws, { type: 'status', sessionId: s.id, session: s.toJSON() });
      return;
    }

    // tool approve/deny — for future interactive mode
    if (t === 'tool.approve' || t === 'tool.deny') {
      // currently yolo auto-runs; reserved for ACP integration
      return;
    }
  });

  ws.on('close', () => console.log('[bridge] client disconnected'));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[kimi-proxy-bridge] listening on 0.0.0.0:${PORT}`);
  console.log(`[kimi-proxy-bridge] kimi binary: ${KIMI_BIN}`);
  console.log(`[kimi-proxy-bridge] work root: ${WORK_ROOT}`);
});
