/**
 * Kimi Proxy Bridge v1.5 — WebSocket front-end for Kimi Code CLI.
 *
 * Applies to Kimi Code CLI 0.38+:
 *  - `kimi -p "<prompt>" --output-format stream-json` emits OpenAI-style JSONL:
 *      {"role":"meta","type":"system.version","version":"0.38.0"}
 *      {"role":"assistant","tool_calls":[{"type":"function","id":"call_...","function":{"name":"Bash","arguments":"{...}"}}]}
 *      {"role":"tool","tool_call_id":"call_...","content":"..."}
 *      {"role":"assistant","content":"..."}
 *      {"role":"meta","type":"session.resume_hint","session_id":"session_...","command":"kimi -r session_...","content":"..."}
 *  - `-p` cannot be combined with `-y` / `--auto` (rejected by CLI), so tools auto-run in prompt mode.
 *  - Multi-turn continues via the resume hint: `kimi -r <session_id> -p ...`.
 *
 * Wire protocol (app <-> bridge), JSON objects:
 *   C->S: ping, session.create{name,workDir,model}, session.list, session.delete{id},
 *         session.rename{id,name}, prompt{sessionId,content}, interrupt{sessionId},
 *         config{sessionId,yolo,planMode,model}, tool.approve/deny (reserved)
 *   S->C: connected, pong, session.list{sessions[]}, session.created{session},
 *         content.delta{sessionId,delta}, thinking.delta{sessionId,delta},
 *         tool.call{sessionId,toolCallId,name,arguments},
 *         tool.output{sessionId,toolCallId,output}, tool.status{sessionId,toolCallId,status,durationMs},
 *         status{sessionId,status}, turn.complete{sessionId,code,durationMs},
 *         error{sessionId,message}
 *
 * Run: node server.js   (PORT / KIMI_BIN / KIMI_WORK_ROOT env overrides)
 */

const http = require('http');
const { WebSocketServer } = require('ws');
const { spawn } = require('child_process');
const { randomUUID } = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PORT = parseInt(process.env.PORT || '8765', 10);

function defaultKimiBin() {
  if (process.env.KIMI_BIN) return process.env.KIMI_BIN;
  if (os.platform() === 'win32') return 'C:\\Users\\Admin\\.kimi-code\\bin\\kimi.exe';
  return path.join(os.homedir(), '.kimi-code', 'bin', 'kimi');
}
const KIMI_BIN = defaultKimiBin();

function defaultWorkRoot() {
  if (process.env.KIMI_WORK_ROOT) return process.env.KIMI_WORK_ROOT;
  return path.join(os.homedir(), '.kimi-code', 'kimi-proxy-sessions');
}
const WORK_ROOT = defaultWorkRoot();
if (!fs.existsSync(WORK_ROOT)) fs.mkdirSync(WORK_ROOT, { recursive: true });

/** @type {Map<string, Session>} */
const sessions = new Map();

class Session {
  constructor(id, name, workDir) {
    this.id = id;
    this.name = name || `Session ${id.slice(0, 6)}`;
    this.workDir = workDir || path.join(WORK_ROOT, id);
    this.status = 'idle';
    this.yolo = true; // prompt mode auto-runs tools; kept for future ACP mode
    this.planMode = false;
    this.model = null;
    this.kimiSessionId = null; // resume id returned by kimi
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
      thinkingEnabled: true,
    };
  }
}

function send(ws, obj) {
  if (ws && ws.readyState === 1) ws.send(JSON.stringify(obj));
}

function broadcastTo(sessionId, obj) {
  // single-client bridge for now; forward to all connected sockets
  for (const ws of wss.clients) {
    if (ws.readyState === 1) ws.send(JSON.stringify(obj));
  }
}

/** Map a kimi stream-json line to app protocol events. */
function mapStreamEvent(session, evt) {
  const role = evt.role;
  const t = evt.type;

  if (role === 'meta') {
    if (t === 'system.version') return;
    if (t === 'session.resume_hint' && evt.session_id) {
      session.kimiSessionId = evt.session_id;
    }
    return;
  }

  if (role === 'assistant') {
    // tool calls
    if (Array.isArray(evt.tool_calls)) {
      for (const tc of evt.tool_calls) {
        const fn = tc.function || {};
        let args = fn.arguments || {};
        if (typeof args === 'string') {
          try { args = JSON.parse(args); } catch { args = { raw: args }; }
        }
        broadcastTo(session.id, {
          type: 'tool.call',
          sessionId: session.id,
          toolCallId: tc.id || randomUUID(),
          name: fn.name || 'tool',
          arguments: args,
        });
      }
    }
    // reasoning / thinking
    const reasoning = evt.reasoning_content || evt.reasoning || (evt.content && evt.content.reasoning);
    if (reasoning && typeof reasoning === 'string') {
      broadcastTo(session.id, { type: 'thinking.delta', sessionId: session.id, delta: reasoning });
      session.status = 'thinking';
    }
    // content
    const content = evt.content;
    if (typeof content === 'string' && content) {
      broadcastTo(session.id, { type: 'content.delta', sessionId: session.id, delta: content });
      session.status = 'streaming';
    }
    return;
  }

  if (role === 'tool') {
    broadcastTo(session.id, {
      type: 'tool.output',
      sessionId: session.id,
      toolCallId: evt.tool_call_id || '',
      output: typeof evt.content === 'string' ? evt.content : JSON.stringify(evt.content || ''),
    });
    broadcastTo(session.id, {
      type: 'tool.status',
      sessionId: session.id,
      toolCallId: evt.tool_call_id || '',
      status: 'success',
    });
    return;
  }

  if (role === 'user') {
    // echoes back user content (only in multi-turn continuation lines); ignore
    return;
  }
}

function buildArgs(session, prompt) {
  const args = ['-p', prompt, '--output-format', 'stream-json'];
  if (session.kimiSessionId) args.push('-r', session.kimiSessionId);
  if (session.model) args.push('-m', session.model);
  if (session.planMode) args.push('--plan');
  return args;
}

function runKimiPrompt(session, prompt, ws) {
  return new Promise((resolve) => runOnce(session, prompt, ws, resolve, false));
}

function runOnce(session, prompt, ws, resolve, retried) {
  const started = Date.now();
  session.status = 'streaming';
  session.updatedAt = new Date().toISOString();
  send(ws, { type: 'status', sessionId: session.id, status: 'streaming' });

  const args = buildArgs(session, prompt);
  const proc = spawn(KIMI_BIN, args, {
    cwd: session.workDir,
    env: { ...process.env },
    windowsHide: true,
  });
  session.proc = proc;

  let buffer = '';
  let stderrText = '';
  const flushLine = (line) => {
    line = line.trim();
    if (!line) return;
    let evt;
    try { evt = JSON.parse(line); } catch {
      send(ws, { type: 'content.delta', sessionId: session.id, delta: line + '\n' });
      return;
    }
    mapStreamEvent(session, evt);
  };

  proc.stdout.on('data', (chunk) => {
    buffer += chunk.toString();
    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() || '';
    for (const line of lines) flushLine(line);
  });

  proc.stderr.on('data', (chunk) => {
    const t = chunk.toString();
    stderrText += t;
    if (/error/i.test(t) && !/error-?file/i.test(t)) {
      send(ws, { type: 'error', sessionId: session.id, message: t.slice(0, 500) });
    }
  });

  proc.on('close', (code) => {
    // Kimi API thinking-mode contract: a follow-up request must echo back
    // reasoning_content. If resuming a session hits this error, the session's
    // context is unusable — retry once on a fresh session instead of dying.
    if (code !== 0 && /reasoning_content/i.test(stderrText) && !retried) {
      console.log(`[bridge] reasoning_content error on ${session.id}; retrying fresh`);
      session.kimiSessionId = null; // abandon the poisoned resume context
      send(ws, { type: 'error', sessionId: session.id, message: 'Session context invalid (thinking-mode); retrying on a fresh session…' });
      runOnce(session, prompt, ws, resolve, true);
      return;
    }
    if (buffer.trim()) flushLine(buffer);
    session.status = 'idle';
    session.proc = null;
    session.messageCount += 1;
    session.updatedAt = new Date().toISOString();
    const durationMs = Date.now() - started;
    send(ws, { type: 'turn.complete', sessionId: session.id, code, durationMs });
    send(ws, { type: 'status', sessionId: session.id, status: 'idle', session: session.toJSON() });
    resolve(code);
  });

  proc.on('error', (err) => {
    session.status = 'error';
    session.proc = null;
    send(ws, { type: 'error', sessionId: session.id, message: err.message });
    send(ws, { type: 'turn.complete', sessionId: session.id, code: 1, durationMs: Date.now() - started });
    resolve(1);
  });
}

function interruptSession(session) {
  if (session.proc) {
    try { session.proc.kill('SIGTERM'); } catch (_) {}
    session.proc = null;
  }
  session.status = 'idle';
}

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
    res.end(JSON.stringify({ ok: true, sessions: sessions.size, port: PORT, kimiBin: KIMI_BIN, workRoot: WORK_ROOT }));
    return;
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  console.log(`[bridge] client connected ${new Date().toISOString()}`);
  send(ws, { type: 'connected' });
  send(ws, {
    type: 'session.list',
    sessions: Array.from(sessions.values()).map((s) => s.toJSON()),
  });

  ws.on('message', async (raw) => {
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch { return; }
    const t = msg.type;

    if (t === 'ping') { send(ws, { type: 'pong', ts: msg.ts || Date.now() }); return; }

    if (t === 'session.create') {
      const id = randomUUID();
      const s = new Session(id, msg.name, msg.workDir);
      if (msg.model) s.model = msg.model;
      sessions.set(id, s);
      send(ws, { type: 'session.created', session: s.toJSON() });
      return;
    }

    if (t === 'session.list') {
      send(ws, { type: 'session.list', sessions: Array.from(sessions.values()).map((s) => s.toJSON()) });
      return;
    }

    if (t === 'session.delete') {
      const s = sessions.get(msg.sessionId);
      if (s) { if (s.proc) interruptSession(s); sessions.delete(s.id); }
      send(ws, { type: 'session.deleted', sessionId: msg.sessionId });
      return;
    }

    if (t === 'session.rename') {
      const s = sessions.get(msg.sessionId);
      if (s && msg.name) { s.name = msg.name; s.updatedAt = new Date().toISOString(); }
      send(ws, { type: 'session.renamed', sessionId: msg.sessionId, session: s && s.toJSON() });
      return;
    }

    if (t === 'prompt') {
      const s = sessions.get(msg.sessionId);
      if (!s) { send(ws, { type: 'error', sessionId: msg.sessionId, message: 'session not found' }); return; }
      const prompt = msg.content || '';
      if (!prompt.trim()) return;
      runKimiPrompt(s, prompt, ws); // fire and forget
      return;
    }

    if (t === 'interrupt') {
      const s = sessions.get(msg.sessionId);
      if (s) {
        interruptSession(s);
        send(ws, { type: 'turn.complete', sessionId: s.id, code: -1 });
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

    // reserved for future interactive (ACP) mode
    if (t === 'tool.approve' || t === 'tool.deny') return;
  });

  ws.on('close', () => console.log('[bridge] client disconnected'));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[kimi-proxy-bridge v1.5] listening on 0.0.0.0:${PORT}`);
  console.log(`[kimi-proxy-bridge] kimi binary: ${KIMI_BIN}`);
  console.log(`[kimi-proxy-bridge] work root: ${WORK_ROOT}`);
});
