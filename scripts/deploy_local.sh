#!/bin/bash
# Smart local deploy for CG6 Flights
# - Hot restarts if Flutter is already running
# - Full launch otherwise
# - Waits for DDC compilation before opening Chrome

FLUTTER_BIN="/Users/franciscobances1997/flutter/flutter/bin/flutter"
PORT=8080
URL="http://localhost:$PORT"

# ── 1. Cleanup old Chrome instances ──────────────────────────
echo "Cleaning up..."
scripts/cleanup_flutter_local.sh 2>/dev/null

# ── 2. Check if Flutter is already running on port ───────────
PID=$(lsof -nP -iTCP:$PORT -sTCP:LISTEN -t 2>/dev/null | head -1)

if [ -n "$PID" ] && ps -p $PID -o command= 2>/dev/null | grep -q "flutter_tools"; then
  # ── Hot restart via stdin ─────────────────────────────────
  echo "Flutter is running (PID $PID). Sending hot restart..."
  echo "R" > /proc/$PID/fd/0 2>/dev/null || {
    # /proc not available on macOS, send via Dart VM Service
    WS_URL=$(curl -s http://localhost:$PORT/ 2>/dev/null | grep -o 'ws://[^"]*' | head -1)
    if [ -n "$WS_URL" ]; then
      echo "Hot restart via VM Service..."
    fi
    echo "Cannot hot restart interactively. Restarting..."
    kill $PID 2>/dev/null
    sleep 2
    PID=""
  }
  sleep 5
fi

# ── 3. Full launch if not running ────────────────────────────
if [ -z "$PID" ] || ! ps -p $PID > /dev/null 2>&1; then
  echo "Launching Flutter..."
  $FLUTTER_BIN run -d chrome --web-port=$PORT --dart-define-from-file=.env.json 2>&1 &
  FLUTTER_PID=$!
fi

# ── 4. Wait for DDC compilation to complete ──────────────────
# When compiling, main.dart.js request hangs 60-120s.
# When done, it responds in <1s.
echo "Waiting for DDC compilation..."
while true; do
  START=$(date +%s)
  curl -s --max-time 10 "$URL/main.dart.js" > /dev/null 2>&1
  ELAPSED=$(($(date +%s) - START))
  if [ "$ELAPSED" -lt 5 ]; then
    echo "Compilation complete (${ELAPSED}s response)"
    break
  fi
  sleep 3
done

# ── 6. Open Chrome ───────────────────────────────────────────
osascript -e 'tell application "Google Chrome" to open location "'$URL'"'
echo "Ready: $URL"
