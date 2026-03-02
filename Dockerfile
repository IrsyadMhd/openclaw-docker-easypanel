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
      vim \
      htop \
      procps \
      rclone \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Rclone config — stored in persistent volume, symlinked to default path
RUN mkdir -p /root/.openclaw/rclone /root/.config \
    && ln -s /root/.openclaw/rclone /root/.config/rclone \
    && touch /root/.openclaw/rclone/rclone.conf

# Install OpenClaw and Gemini CLI globally
RUN npm install -g openclaw@2026.2.26 @google/gemini-cli

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
