# Kimi Proxy

Ultra-fast, low-latency remote client for **Kimi Code CLI**.

Premium dark lacquer UI · live thinking stream · expandable tool cards · multi-session · YOLO / Plan mode · WebSocket bridge to your VPS.

## Status

Early scaffold. Core Flutter structure, design system, models, bridge protocol, and main screens are in place.

## Design

- Lacquer black `#0A0B0F`
- Scarce teal accent `#2DD4BF`
- Amber thinking `#F59E0B`
- JetBrains Mono for code / tools
- Hairline elevation, no generic AI slop

## Run

```bash
flutter pub get
flutter run -d chrome
```

## Bridge

Default WebSocket: `ws://85.121.148.62:8765`  
A small Node/Python bridge on the VPS will speak the protocol defined in `lib/services/bridge_service.dart`.

## Next

- VPS bridge service that drives Kimi Code CLI / ACP
- Full streaming fidelity
- Config editors
- GitHub Pages deploy for live preview
- APK build
