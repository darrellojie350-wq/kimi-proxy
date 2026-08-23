/* ============================================================================
 * Kimi Proxy Web — bridge client (Agent B / infra-js)
 * WebSocket client for the kimi-proxy bridge (server.js, port 8765).
 * Contract: ARCHITECTURE.md §3 (bus events) + §5 (wire protocol).
 *
 * Behaviors:
 *  - connect(url)/disconnect()/send(obj); status getter.
 *  - on open: send ping, wait for `connected`; 15s heartbeat (ping every beat,
 *    close if 3 beats miss their pong — reconnects via onclose).
 *  - auto-reconnect with exponential backoff 1s→2s→4s→…max 30s.
 *  - on (re)connect, re-send session.list.
 *  - every inbound wire event is routed to Kimi.bus with the §3 event names.
 *  - session objects in Kimi.state are mutated in place (deltas append, tool
 *    entries push/update, turn.complete finalizes, status updates).
 *
 * Session id reconciliation: the app keeps its own stable `session.id`, while
 * wire calls must use the server's `session.serverId` (a server randomUUID).
 * `send()` translates automatically; inbound events reconcile by serverId and
 * adopt pending local sessions (matched by name when no serverId yet).
 * ========================================================================== */
(function () {
  'use strict';

  var K = window.Kimi;
  if (!K) throw new Error('kimi.js must load before bridge.js');

  var HEARTBEAT_MS = 15000;   // send ping every 15s
  var PONG_TIMEOUT_MS = 45000; // 3 missed beats => force reconnect
  var CONNECTED_TIMEOUT_MS = 5000; // tolerance for bridges that skip `connected`
  var BACKOFF_START_MS = 1000;
  var BACKOFF_MAX_MS = 30000;

  var ws = null;
  var heartbeatTimer = null;
  var connectedTimer = null;
  var reconnectTimer = null;
  var backoffMs = BACKOFF_START_MS;
  var lastPongAt = 0;
  var manualClose = false;
  var url = null;

  /* ------------------------------------------------------------- helpers */

  function emit(evt, data) { K.bus.emit(evt, data); }

  function setConnection(status) {
    if (K.state.connection === status) return;
    K.state.connection = status;
    emit('connection.change', { status: status });
  }

  function findSession(id) { return K.sessions.get(id); }

  function findTool(session, toolCallId) {
    if (!session) return null;
    for (var i = 0; i < session.tools.length; i++) {
      if (session.tools[i].id === toolCallId) return session.tools[i];
    }
    return null;
  }

  function lastStreamingMsg(session) {
    if (!session) return null;
    for (var i = session.messages.length - 1; i >= 0; i--) {
      if (session.messages[i].role === 'assistant' && session.messages[i].streaming) return session.messages[i];
    }
    return null;
  }

  /* Create (or reuse) the assistant message that the current turn streams into. */
  function activeMsg(session) {
    var m = lastStreamingMsg(session);
    if (m) return m;
    m = {
      id: K.uid('m_'),
      role: 'assistant',
      content: '',
      thinking: null,
      toolCalls: [],
      ts: Date.now(),
      streaming: true,
    };
    session.messages.push(m);
    return m;
  }

  /* ------------------------------------------------------- reconciliation */

  function adoptOrUpdate(serverSession) {
    if (!serverSession || !serverSession.id) return null;
    var i;
    // 1) exact match by serverId
    for (i = 0; i < K.state.sessions.length; i++) {
      if (K.state.sessions[i].serverId === serverSession.id) {
        applyServerFields(K.state.sessions[i], serverSession);
        return K.state.sessions[i];
      }
    }
    // 2) pending local session (created while online, awaiting server echo) —
    //    matched by name + no serverId yet.
    for (i = 0; i < K.state.sessions.length; i++) {
      var s = K.state.sessions[i];
      if (!s.serverId && s.name === serverSession.name) {
        s.serverId = serverSession.id;
        applyServerFields(s, serverSession);
        return s;
      }
    }
    // 3) brand-new app session from the server
    var ns = K.sessions._fromServer(serverSession);
    if (ns) K.state.sessions.push(ns);
    return ns;
  }

  function applyServerFields(s, ss) {
    if (ss.name) s.name = ss.name;
    if (ss.workDir) s.workDir = ss.workDir;
    if (ss.status) s.status = ss.status;
    if (typeof ss.model !== 'undefined' && ss.model !== null) s.model = ss.model;
    if (typeof ss.yolo === 'boolean') s.yolo = ss.yolo;
    if (typeof ss.planMode === 'boolean') s.planMode = ss.planMode;
    if (ss.messageCount) s.messageCount = ss.messageCount;
    if (ss.createdAt) s.createdAt = new Date(ss.createdAt).getTime();
    if (ss.updatedAt) s.updatedAt = new Date(ss.updatedAt).getTime();
  }

  function dropSession(sessionId) {
    var s = findSession(sessionId);
    if (!s) {
      // also try matching by serverId (delete acked for a synced session)
      for (var i = 0; i < K.state.sessions.length; i++) {
        if (K.state.sessions[i].serverId === sessionId) { s = K.state.sessions[i]; break; }
      }
    }
    if (!s) return;
    var i = K.state.sessions.indexOf(s);
    K.state.sessions.splice(i, 1);
    if (K.state.activeId === s.id) {
      K.state.activeId = K.state.sessions.length ? K.state.sessions[0].id : null;
      if (K.state.activeId) emit('session.selected', { id: K.state.activeId });
    }
    K.sessions._persist();
  }

  /* --------------------------------------------------------- wire routing */

  function handleMessage(raw) {
    var msg;
    try { msg = JSON.parse(raw); } catch (e) { return; }
    if (!msg || !msg.type) return;
    var type = msg.type;
    var sid = msg.sessionId;
    var session = sid ? findSession(sid) || findByServerId(sid) : null;
    var m;

    switch (type) {
      case 'connected':
        stopConnectedTimer();
        backoffMs = BACKOFF_START_MS;
        setConnection('online');
        sendWire({ type: 'session.list' });
        break;

      case 'pong':
        lastPongAt = Date.now();
        break;

      case 'session.list':
        if (Array.isArray(msg.sessions)) {
          for (var i = 0; i < msg.sessions.length; i++) {
            adoptOrUpdate(msg.sessions[i]);
          }
          K.sessions._persist();
          emit('sessions.changed');
        }
        break;

      case 'session.created':
        {
          var ns2 = adoptOrUpdate(msg.session);
          K.sessions._persist();
          if (ns2) emit('session.created', { session: ns2 });
          emit('sessions.changed');
        }
        break;

      case 'session.deleted':
        dropSession(sid);
        emit('session.deleted', { sessionId: sid });
        emit('sessions.changed');
        break;

      case 'session.renamed':
        session = adoptOrUpdate(msg.session);
        K.sessions._persist();
        if (session) emit('sessions.changed');
        break;

      case 'status':
        if (session) {
          session.status = msg.status || session.status;
          if (msg.session) applyServerFields(session, msg.session);
          K.sessions._persist();
          emit('session.status', { sessionId: sid, status: session.status });
          emit('sessions.changed');
        }
        break;

      case 'content.delta':
        if (session) {
          m = activeMsg(session);
          m.content += msg.delta || '';
          K.sessions._persist();
          emit('message.delta', { sessionId: sid, msgId: m.id, delta: msg.delta || '' });
        }
        break;

      case 'thinking.delta':
        if (session) {
          m = activeMsg(session);
          m.thinking = (m.thinking || '') + (msg.delta || '');
          K.sessions._persist();
          emit('thinking.delta', { sessionId: sid, msgId: m.id, delta: msg.delta || '' });
        }
        break;

      case 'tool.call':
        if (session) {
          m = activeMsg(session);
          var tc = {
            id: msg.toolCallId,
            name: msg.name || 'tool',
            arguments: msg.arguments || {},
            status: 'running',
            output: null,
            startedAt: Date.now(),
            durationMs: null,
          };
          session.tools.push(tc);
          if (m.toolCalls) m.toolCalls.push(tc.id);
          session.status = 'toolRunning';
          K.sessions._persist();
          emit('tool.call', {
            sessionId: sid, toolCallId: tc.id, name: tc.name, arguments: tc.arguments,
          });
          emit('session.status', { sessionId: sid, status: 'toolRunning' });
        }
        break;

      case 'tool.output':
        if (session) {
          var to = findTool(session, msg.toolCallId);
          if (to) { to.output = msg.output || ''; K.sessions._persist(); }
          emit('tool.output', { sessionId: sid, toolCallId: msg.toolCallId, output: msg.output || '' });
        }
        break;

      case 'tool.status':
        if (session) {
          var ts2 = findTool(session, msg.toolCallId);
          if (ts2) {
            ts2.status = msg.status || 'success';
            ts2.durationMs = ts2.startedAt ? Date.now() - ts2.startedAt : null;
            K.sessions._persist();
          }
          emit('tool.status', { sessionId: sid, toolCallId: msg.toolCallId, status: msg.status || 'success' });
        }
        break;

      case 'turn.complete':
        if (session) {
          m = lastStreamingMsg(session);
          if (m) m.streaming = false;
          session.status = msg.code === 0 ? 'idle' : (msg.code === -1 ? 'idle' : 'error');
          K.sessions._persist();
          emit('turn.complete', {
            sessionId: sid, code: typeof msg.code === 'number' ? msg.code : 0,
            durationMs: msg.durationMs || 0,
          });
          emit('session.status', { sessionId: sid, status: session.status });
          emit('sessions.changed');
        }
        break;

      case 'error':
        if (session) {
          session.status = 'error';
          K.sessions._persist();
          emit('session.status', { sessionId: sid, status: 'error' });
        }
        emit('bridge.error', { message: msg.message || 'Bridge error' });
        break;

      default:
        // unknown wire type — ignore
        break;
    }
  }

  function findByServerId(serverId) {
    for (var i = 0; i < K.state.sessions.length; i++) {
      if (K.state.sessions[i].serverId === serverId) return K.state.sessions[i];
    }
    return null;
  }

  /* ---------------------------------------------------------- connection */

  function stopConnectedTimer() {
    if (connectedTimer) { clearTimeout(connectedTimer); connectedTimer = null; }
  }

  function stopHeartbeat() {
    if (heartbeatTimer) { clearInterval(heartbeatTimer); heartbeatTimer = null; }
  }

  function stopReconnect() {
    if (reconnectTimer) { clearTimeout(reconnectTimer); reconnectTimer = null; }
  }

  function sendWire(obj) {
    if (ws && ws.readyState === 1) {
      try { ws.send(JSON.stringify(obj)); } catch (e) { /* noop */ }
    }
  }

  function startHeartbeat() {
    stopHeartbeat();
    lastPongAt = Date.now();
    heartbeatTimer = setInterval(function () {
      if (!ws || ws.readyState !== 1) return;
      if (lastPongAt && Date.now() - lastPongAt > PONG_TIMEOUT_MS) {
        // stale connection — close to trigger reconnect
        try { ws.close(); } catch (e) {}
        return;
      }
      sendWire({ type: 'ping', ts: Date.now() });
    }, HEARTBEAT_MS);
  }

  function scheduleReconnect() {
    if (!K.bridge.autoReconnect || manualClose) return;
    stopReconnect();
    setConnection('connecting');
    reconnectTimer = setTimeout(function () {
      reconnectTimer = null;
      openSocket();
    }, backoffMs);
    backoffMs = Math.min(backoffMs * 2, BACKOFF_MAX_MS);
  }

  function openSocket() {
    if (ws) {
      try { ws.onclose = null; ws.close(); } catch (e) {}
      ws = null;
    }
    setConnection('connecting');
    var target = url || defaultUrl();
    try {
      ws = new WebSocket(target);
    } catch (e) {
      emit('bridge.error', { message: 'Invalid WebSocket URL: ' + target });
      scheduleReconnect();
      return;
    }

    ws.onopen = function () {
      sendWire({ type: 'ping', ts: Date.now() });
      startHeartbeat();
      // Wait for `connected` before declaring online, but don't hang forever
      // on bridges that omit it.
      stopConnectedTimer();
      connectedTimer = setTimeout(function () {
        if (ws && ws.readyState === 1 && K.state.connection === 'connecting') {
          backoffMs = BACKOFF_START_MS;
          setConnection('online');
          sendWire({ type: 'session.list' });
        }
      }, CONNECTED_TIMEOUT_MS);
    };

    ws.onmessage = function (evt) { handleMessage(evt.data); };

    ws.onerror = function () {
      emit('bridge.error', { message: 'Bridge connection error' });
    };

    ws.onclose = function () {
      stopHeartbeat();
      stopConnectedTimer();
      ws = null;
      setConnection('offline');
      if (!manualClose) scheduleReconnect();
    };
  }

  function defaultUrl() {
    if (typeof location === 'undefined') return 'ws://localhost:8765';
    var proto = location.protocol === 'https:' ? 'wss' : 'ws';
    return proto + '://' + location.hostname + ':8765';
  }

  /* ------------------------------------------------------------- public */

  var bridge = {
    autoReconnect: true,

    get status() { return K.state.connection; },

    connect: function (urlOrSettings) {
      manualClose = false;
      var u = urlOrSettings;
      if (typeof u !== 'string' || !u) {
        u = K.settings.get('bridgeUrl', '') || defaultUrl();
      }
      url = u;
      backoffMs = BACKOFF_START_MS;
      stopReconnect();
      openSocket();
    },

    disconnect: function () {
      manualClose = true;
      stopReconnect();
      stopHeartbeat();
      stopConnectedTimer();
      if (ws) {
        try { ws.onclose = null; ws.close(); } catch (e) {}
        ws = null;
      }
      setConnection('offline');
    },

    send: function (obj) {
      if (!obj || typeof obj !== 'object') return;
      var session = obj.sessionId ? findSession(obj.sessionId) : null;
      var wire = {};
      for (var k in obj) {
        if (Object.prototype.hasOwnProperty.call(obj, k)) wire[k] = obj[k];
      }

      // Translate app session id -> server id for the wire.
      if (session && session.serverId && wire.sessionId === session.id) {
        wire.sessionId = session.serverId;
      }

      // Local-state side effects for turn-producing messages.
      if (wire.type === 'prompt' && session) {
        // new turn: reset activity, append the user message + assistant placeholder
        session.tools = [];
        session.status = 'streaming';
        session.messages.push({
          id: K.uid('m_'), role: 'user', content: String(wire.content || ''), thinking: null,
          toolCalls: [], ts: Date.now(), streaming: false,
        });
        session.messages.push({
          id: K.uid('m_'), role: 'assistant', content: '', thinking: null,
          toolCalls: [], ts: Date.now(), streaming: true,
        });
        K.sessions._touch(session);
        K.sessions._persist();
        emit('sessions.changed');
      }

      if (wire.type === 'config' && session) {
        if (typeof wire.yolo === 'boolean') session.yolo = wire.yolo;
        if (typeof wire.planMode === 'boolean') session.planMode = wire.planMode;
        if (wire.model) session.model = wire.model;
        K.sessions._touch(session);
        K.sessions._persist();
        emit('sessions.changed');
      }

      if (wire.type === 'interrupt' && session) {
        var streaming = lastStreamingMsg(session);
        if (streaming) streaming.streaming = false;
        session.status = 'idle';
        K.sessions._persist();
        emit('session.status', { sessionId: session.id, status: 'idle' });
      }

      if (ws && ws.readyState === 1) {
        sendWire(wire);
      } else {
        emit('bridge.error', { message: 'Bridge not connected — message not sent' });
      }
    },
  };

  K.bridge = bridge;
})();
