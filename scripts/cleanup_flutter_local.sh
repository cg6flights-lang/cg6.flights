#!/usr/bin/env bash
set -euo pipefail

ports=(43210 8080 8082)

for port in "${ports[@]}"; do
  pids="$(lsof -tiTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "${pids}" ]]; then
    echo "Stopping listeners on port ${port}: ${pids}"
    kill ${pids} 2>/dev/null || true
    sleep 1
    remaining="$(lsof -tiTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true)"
    if [[ -n "${remaining}" ]]; then
      echo "Force stopping listeners on port ${port}: ${remaining}"
      kill -9 ${remaining} 2>/dev/null || true
    fi
  fi
done

chrome_pids="$(
  ps -axo pid,command |
    awk '/flutter_tools_chrome_device/ && /claude-501/ { print $1 }'
)"

if [[ -n "${chrome_pids}" ]]; then
  echo "Stopping Claude Flutter Chrome instances: ${chrome_pids}"
  kill ${chrome_pids} 2>/dev/null || true
  sleep 1
  force_chrome_pids="$(
    ps -axo pid,command |
      awk '/flutter_tools_chrome_device/ && /claude-501/ { print $1 }'
  )"
  if [[ -n "${force_chrome_pids}" ]]; then
    echo "Force stopping Claude Flutter Chrome instances: ${force_chrome_pids}"
    kill -9 ${force_chrome_pids} 2>/dev/null || true
  fi
fi

echo "Flutter local cleanup complete."
