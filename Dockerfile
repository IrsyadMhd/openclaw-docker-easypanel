# =============================================================================
# OpenClaw — Simple VPS-Style Container for ARM64 (EasyPanel)
# =============================================================================
# Konsep: Container ini seperti VPS kosong yang sudah terinstall openclaw.
# Tinggal exec ke terminal dan jalankan: openclaw onboard
#
# Build:  docker build --platform linux/arm64 -t openclaw:arm64 .
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
      unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set timezone to Asia/Jakarta (WIB)
ENV TZ=Asia/Jakarta
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Rclone config — stored in persistent volume, symlinked to default path
RUN mkdir -p /root/.openclaw/rclone /root/.config \
    && ln -s /root/.openclaw/rclone /root/.config/rclone \
    && touch /root/.openclaw/rclone/rclone.conf

# Install OpenClaw globally
RUN npm install -g openclaw@2026.3.24

# Install Kiro CLI (aarch64 zip)
RUN curl --proto '=https' --tlsv1.2 -sSf \
      'https://desktop-release.q.us-east-1.amazonaws.com/latest/kirocli-aarch64-linux.zip' \
      -o /tmp/kirocli.zip \
    && unzip -q /tmp/kirocli.zip -d /tmp/kirocli \
    && /tmp/kirocli/kirocli/install.sh \
    && rm -rf /tmp/kirocli.zip /tmp/kirocli

# Create working directories
RUN mkdir -p /root/.openclaw /root/.openclaw/workspace

# Persistent data
VOLUME ["/root/.openclaw"]

EXPOSE 18789

# Try to start gateway (will work if onboarding is done, silently fail if not)
# Guard: skip if port 18789 already bound (gateway already running)
# Container stays alive either way — run "openclaw onboard" if first time
CMD ["bash", "-c", "\
  echo '🦞 OpenClaw container started.'; \
  if ss -tlnp 2>/dev/null | grep -q ':18789'; then \
    echo '⚠️  Gateway already running on port 18789, skipping...'; \
  else \
    openclaw gateway --port 18789 >> /root/.openclaw/gateway.log 2>&1 & \
    echo $! > /run/openclaw-gateway.pid; \
    echo '🦞 Gateway launched (PID: '\"$!\"', logs: /root/.openclaw/gateway.log)'; \
  fi; \
  echo '💡 First time? Run: openclaw onboard'; \
  echo '🤖 Kiro CLI ready. Run: kiro-cli login'; \
  tail -f /dev/null"]
