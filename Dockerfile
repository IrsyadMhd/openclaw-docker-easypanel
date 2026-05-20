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

FROM --platform=linux/arm64 node:24-bookworm

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
      python3 \
      python3-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set timezone to Asia/Jakarta (WIB)
ENV TZ=Asia/Jakarta
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# -----------------------------------------------------------------------------
# Performance & Resource Controls (PENTING untuk container ARM64 low-memory)
# -----------------------------------------------------------------------------
# Batasi heap Node.js agar tidak rakus RAM (default V8 bisa sampai 1.5-2GB).
# Sesuaikan nilai ini: ~60% dari RAM container Anda.
#   Contoh: 1GB RAM container → 600, 2GB → 1200, 4GB → 2400
ENV NODE_OPTIONS=--max-old-space-size=1200

# Matikan auto-update background agar tidak ada CPU spike tersembunyi
# saat startup maupun saat chat. Upgrade manual via: npm install -g openclaw@latest
ENV OPENCLAW_NO_AUTO_UPDATE=1

# Kurangi npm verbosity saat openclaw menjalankan proses internal npm
ENV OPENCLAW_NPM_LOGLEVEL=warn

# Rclone config — stored in persistent volume, symlinked to default path
RUN mkdir -p /root/.openclaw/rclone /root/.config \
    && ln -s /root/.openclaw/rclone /root/.config/rclone \
    && touch /root/.openclaw/rclone/rclone.conf

# Install OpenClaw globally
# 2026.5.12 changelog penting:
#   - Leaner installs: WhatsApp, Slack, Bedrock, Vertex di-eksternalisasi dari core
#   - Memory leak fix: transcript streaming helpers (RSS growth 10x lebih hemat)
#   - Gateway protocol v4: explicit deltaText/replace frames
#   - Telegram: isolated polling, durable spooling, better group-media handling
#   - Security: per-sender tool permissions, approval wajib untuk device pairing
#   - Codex: OpenAI agent turns on native Codex harness
#   - Plugin management: peer-dependency preservation, pnpm 11 support
#   - Cron & UI: inspect cron by ID, recovery panel for blank dashboards
RUN npm install -g openclaw@2026.5.12

# Install Python packages (baked into image, persists across restarts)
RUN pip3 install --break-system-packages mysql-connector-python

# Install gogcli (gog) — Google Suite CLI (Gmail, GCal, GDrive, Contacts, etc.)
# https://github.com/steipete/gogcli
ARG TARGETARCH
ARG GOG_VERSION=0.12.0
RUN curl -fsSL "https://github.com/steipete/gogcli/releases/download/v${GOG_VERSION}/gogcli_${GOG_VERSION}_linux_${TARGETARCH}.tar.gz" \
      | tar -xz -C /usr/local/bin gog \
    && chmod +x /usr/local/bin/gog

# Create working directories
RUN mkdir -p /root/.openclaw /root/.openclaw/workspace

# Persistent data
VOLUME ["/root/.openclaw"]

EXPOSE 18789

# Try to start gateway (will work if onboarding is done, silently fail if not)
# Guard: skip if port 18789 already bound (gateway already running)
# Container stays alive either way — run "openclaw onboard" if first time
#
# Gateway dijalankan sebagai background process (&) — ini adalah
# "foreground gateway run" dari sudut pandang openclaw, sehingga self-respawn
# loop tidak terjadi.
#
# Plugin gc-provider di-install otomatis jika belum ada (idempotent).
# Data plugin tersimpan di /root/.openclaw (persistent volume).
CMD ["bash", "-c", "\
  echo '🦞 OpenClaw container started.'; \
  echo \"   NODE_OPTIONS : $NODE_OPTIONS\"; \
  echo \"   AUTO_UPDATE  : $([ \"$OPENCLAW_NO_AUTO_UPDATE\" = '1' ] && echo DISABLED || echo ENABLED)\"; \
  if ss -tlnp 2>/dev/null | grep -q ':18789'; then \
    echo '⚠️  Gateway already running on port 18789, skipping...'; \
  else \
    openclaw gateway --port 18789 >> /root/.openclaw/gateway.log 2>&1 & \
    echo $! > /run/openclaw-gateway.pid; \
    echo '🦞 Gateway launched (PID: '\"$!\"', logs: /root/.openclaw/gateway.log)'; \
  fi; \
  if openclaw plugins list 2>/dev/null | grep -q 'gc-provider'; then \
    echo '✅ Plugin gc-provider already installed.'; \
  else \
    echo '📦 Installing plugin gc-provider...'; \
    openclaw plugins install clawhub:gc-provider 2>&1 && \
      echo '✅ Plugin gc-provider installed successfully.' || \
      echo '⚠️  Plugin gc-provider install failed (run manually after onboard).'; \
  fi; \
  echo '💡 First time? Run: openclaw onboard'; \
  echo '🔧 Performance tip: openclaw doctor --fix (jalankan setelah onboard)'; \
  tail -f /dev/null"]
