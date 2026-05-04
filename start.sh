#!/usr/bin/env bash
# Hermes Agent container bootstrap script.
# Do NOT use set -e — startup errors are handled per-function.

export PATH="/opt/hermes/.venv/bin:${PATH}"
export HERMES_HOME="${HERMES_HOME:-/root/.hermes}"

# Ensure runtime dirs exist
mkdir -p "${HERMES_HOME}"

start_hermes() {
  echo "⚕ Hermes Agent container started."

  # Check for legacy OpenClaw data and suggest migration
  if [ -d "/root/.openclaw" ] && [ -f "/root/.openclaw/workspace/.soul" ]; then
    if [ ! -f "${HERMES_HOME}/.migrated-from-openclaw" ]; then
      echo ""
      echo "╔═══════════════════════════════════════════════════════════╗"
      echo "║  💡 OpenClaw data detected at /root/.openclaw            ║"
      echo "║  Run: hermes claw migrate                                ║"
      echo "║  This imports persona, memories, skills & API keys.      ║"
      echo "╚═══════════════════════════════════════════════════════════╝"
      echo ""
    fi
  fi

  # Start Hermes gateway in background if not already running
  if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -qE ':(3000|8080)'; then
    echo "⚠️  Hermes gateway already running, skipping..."
  else
    hermes gateway start >> "${HERMES_HOME}/gateway.log" 2>&1 &
    echo $! > /run/hermes-gateway.pid
    echo "⚕ Hermes gateway launched (PID: $!, logs: ${HERMES_HOME}/gateway.log)"
  fi
}

start_hermes

echo "✅ Runtime ready."
echo ""
echo "💡 First time? Run:"
echo "   hermes setup        — Configure model & API keys"
echo "   hermes gateway setup — Configure messaging (Telegram, etc.)"
echo "   hermes doctor       — Diagnose any issues"

# Tail gateway log if it exists
if [ -f "${HERMES_HOME}/gateway.log" ]; then
  tail -f "${HERMES_HOME}/gateway.log" 2>/dev/null &
fi

# Keep container alive
tail -f /dev/null
