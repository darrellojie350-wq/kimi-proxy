#!/bin/bash
# Analyze a screen image with GROQ qwen vision (direct API — bypasses stale MCP process).
# Usage: ./analyze-screen.sh <image_path> [max_tokens] [prompt]
set -e
IMG="$1"
TOKENS="${2:-250}"
PROMPT="${3:-Describe this mobile app screen precisely: layout structure, color palette (hex if visible), component styles (buttons, inputs, cards, chips, nav), spacing/density, typography, status indicators, and specifically what makes it feel premium. Be concrete and concise.}"
KEY="${GROQ_API_KEY:-}"

B64=$(python3 -c "
import base64,sys
with open(sys.argv[1],'rb') as f: print(base64.b64encode(f.read()).decode())
" "$IMG")

python3 - "$KEY" "$B64" "$TOKENS" "$PROMPT" <<'EOF'
import json, subprocess, sys
key, b64, tokens, prompt = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
payload = {
  "model": "qwen/qwen3.6-27b",
  "messages": [{"role": "user", "content": [
    {"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64}},
    {"type": "text", "text": prompt}
  ]}],
  "max_tokens": tokens
}
with open('/tmp/groq_payload.json', 'w') as f:
    json.dump(payload, f)
r = subprocess.run(
    ["curl", "-s", "https://api.groq.com/openai/v1/chat/completions",
     "-H", "Content-Type: application/json",
     "-H", "Authorization: Bearer " + key,
     "-H", "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/126 Safari/537.36",
     "--data-binary", "@/tmp/groq_payload.json"],
    capture_output=True, text=True, timeout=90)
try:
    d = json.loads(r.stdout)
    print(d["choices"][0]["message"]["content"])
except Exception as e:
    print("ERROR:", r.stdout[:500])
EOF
