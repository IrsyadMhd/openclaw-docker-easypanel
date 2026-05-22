#!/usr/bin/env bash
# Hermes Agent container bootstrap script (v0.13.0+).
# Do NOT use set -e — startup errors are handled per-function.

# Activate the venv properly — sets VIRTUAL_ENV, prepends .venv/bin to PATH,
# and ensures `python3` / `hermes` resolve to the venv interpreter, not system.
export VIRTUAL_ENV="/opt/hermes/.venv"
export PATH="${VIRTUAL_ENV}/bin:${PATH}"
export HERMES_HOME="${HERMES_HOME:-/opt/data}"

# Source activate for any tools that check for an "activated" venv.
# shellcheck disable=SC1091
[ -f "${VIRTUAL_ENV}/bin/activate" ] && . "${VIRTUAL_ENV}/bin/activate"

# Ensure runtime dirs exist
mkdir -p "${HERMES_HOME}"

start_hermes() {
  echo "⚕ Hermes Agent container started (v0.13.0)."

  # Check for legacy OpenClaw data and suggest migration
  if [ -d "${HERMES_HOME}/../.openclaw" ] && [ -f "${HERMES_HOME}/../.openclaw/workspace/.soul" ]; then
    if [ ! -f "${HERMES_HOME}/.migrated-from-openclaw" ]; then
      echo ""
      echo "╔═══════════════════════════════════════════════════════════╗"
      echo "║  💡 OpenClaw data detected                               ║"
      echo "║  Run: hermes claw migrate                                ║"
      echo "║  This imports persona, memories, skills & API keys.      ║"
      echo "╚═══════════════════════════════════════════════════════════╝"
      echo ""
    fi
  fi

  echo ""
  echo "💡 First time? Run:"
  echo "   hermes setup        — Configure model & API keys"
  echo "   hermes gateway setup — Configure messaging (Telegram, etc.)"
  echo "   hermes doctor       — Diagnose any issues"
  echo ""

  echo "⚕ Starting Hermes gateway (foreground)..."
  # v0.13.0: Use 'gateway run' for foreground execution (required for Docker).
  # 'hermes gateway' alone no longer starts the process in foreground.
  hermes gateway run
  
  echo "⚠️ Hermes gateway exited."
}

start_hermes

echo "✅ Container is running (kept alive for debugging or setup)."
# Keep container alive if gateway exits (e.g. before first-time setup is complete)
tail -f /dev/null
