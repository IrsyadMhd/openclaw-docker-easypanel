# =============================================================================
# OpenClaw — Simple VPS-Style Container for ARM64 (EasyPanel)
# Base: OpenCloudOS 9
# =============================================================================
# Konsep: Container ini seperti VPS kosong yang sudah terinstall openclaw.
# Tinggal exec ke terminal dan jalankan: openclaw onboard
#
# Build:  docker build --platform linux/arm64 -t openclaw:arm64 .
# Run:    docker run -d --name openclaw -p 18789:18789 openclaw:arm64
# Exec:   docker exec -it openclaw bash
# =============================================================================

FROM --platform=linux/arm64 opencloudos/opencloudos9-minimal

# Install essential tools (like a real VPS)
RUN dnf install -y \
      curl \
      git \
      nano \
      vim-enhanced \
      procps-ng \
      epel-release \
    && dnf install -y htop \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Install rclone via official script
RUN curl -fsSL https://rclone.org/install.sh | bash

# Install Node.js 22 via NodeSource
RUN curl -fsSL https://rpm.nodesource.com/setup_22.x | bash - \
    && dnf install -y nodejs \
    && dnf clean all

# Rclone config — stored in persistent volume, symlinked to default path
RUN mkdir -p /root/.openclaw/rclone /root/.config \
    && ln -s /root/.openclaw/rclone /root/.config/rclone \
    && touch /root/.openclaw/rclone/rclone.conf

# Install OpenClaw and Gemini CLI globally
RUN npm install -g openclaw@2026.2.3 @google/gemini-cli

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
