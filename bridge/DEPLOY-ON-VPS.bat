@echo off
echo === Deploy Kimi Bridge v2 ===
cd /d C:\kimi-proxy-bridge
copy /Y kimi-bridge.js kimi-bridge.js.bak 2>nul
echo Pulling from GitHub...
curl -L -o kimi-bridge.js https://raw.githubusercontent.com/darrellojie350-wq/kimi-proxy/main/bridge/kimi-bridge.js
npm install --omit=dev
echo Restarting scheduled task...
schtasks /End /TN KimiProxyBridge 2>nul
timeout /t 2 /nobreak >nul
schtasks /Run /TN KimiProxyBridge
timeout /t 3 /nobreak >nul
curl -s http://127.0.0.1:9876/health
echo.
echo Done. Health check above should show providers including chatanywhere.
pause
