@echo off
cd /d %~dp0
if not exist node_modules (
  call npm install --omit=dev
)
set KIMI_BRIDGE_PORT=8766
set OPENAI_BASE=http://127.0.0.1:8789/v1
set OPENAI_KEY=ai-proxy-local
set DEFAULT_MODEL=ai-proxy/deepseek-v4-flash
node kimi-bridge.js
