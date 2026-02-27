# =============================================================================
# OpenClaw — Simple VPS-Style Container for ARM64 (EasyPanel)
# =============================================================================
# Konsep: Container ini seperti VPS kosong yang sudah terinstall openclaw.
# Tinggal exec ke terminal dan jalankan: openclaw onboard
#
# Build:  docker build --platform linux/arm64 -f Dockerfile.arm64 -t openclaw:arm64 .
# Run:    docker run -d --name openclaw -p 18789:18789 openclaw:arm64
# Exec:   docker exec -it openclaw bash
# =============================================================================

FROM --platform=linux/arm64 node:22-bookworm

# Install essential tools (like a real VPS)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl \
      git \
      nano \
      htop \
      procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally
RUN npm install -g openclaw@latest

# Create working directories
RUN mkdir -p /root/.openclaw /root/.openclaw/workspace

# Persistent data
VOLUME ["/root/.openclaw"]

EXPOSE 18789

# Try to start gateway (will work if onboarding is done, silently fail if not)
# Container stays alive either way — run "openclaw onboard" if first time
CMD ["bash", "-c", "\
  echo '🦞 OpenClaw container started.'; \
  openclaw gateway --port 18789 >> /root/.openclaw/gateway.log 2>&1 & \
  if [ $? -eq 0 ]; then echo '🦞 Gateway process launched (check logs: /root/.openclaw/gateway.log)'; fi; \
  echo '💡 First time? Run: openclaw onboard'; \
  tail -f /dev/null"]
