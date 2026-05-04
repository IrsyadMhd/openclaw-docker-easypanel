# =============================================================================
# Hermes Agent — ARM64 container for EasyPanel
# =============================================================================
# Purpose:
# - Hermes Agent runtime (AI agent by Nous Research)
# - Built-in migration from OpenClaw via `hermes claw migrate`
# - Services auto-start on container restart
# - Important data paths declared as volumes
#
# Important durability note:
# - For EasyPanel/container recreate/redeploy, bind or named volumes MUST be kept/mounted:
#     /root/.hermes
# - Do not delete the volume when redeploying, or Hermes data can be lost.
# =============================================================================

FROM --platform=linux/arm64 node:22-bookworm

ENV TZ=Asia/Jakarta \
    DEBIAN_FRONTEND=noninteractive \
    PATH=/opt/hermes/.venv/bin:$PATH \
    HERMES_HOME=/root/.hermes \
    PYTHONUNBUFFERED=1

# Essential tools + Hermes dependencies.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      nano \
      vim \
      htop \
      procps \
      unzip \
      python3 \
      python3-pip \
      python3-venv \
      python3-dev \
      build-essential \
      pkg-config \
      libffi-dev \
      netcat-openbsd \
      tzdata \
      ripgrep \
      ffmpeg \
      tini \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Timezone.
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install uv (fast Python package manager by Astral).
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Install Hermes Agent from source.
# Clones the repo, creates a Python 3.11 venv, installs all dependencies.
# Playwright/browser automation is SKIPPED to keep image size small.
ARG HERMES_BRANCH=main
RUN git clone --depth=1 -b "${HERMES_BRANCH}" \
      https://github.com/NousResearch/hermes-agent.git /opt/hermes && \
    cd /opt/hermes && \
    uv venv .venv --python 3.11 && \
    uv pip install --no-cache-dir -e ".[all]" && \
    npm install --prefer-offline --no-audit && \
    npm cache clean --force

# Symlink hermes command to PATH for easy access.
RUN ln -sf /opt/hermes/hermes /usr/local/bin/hermes

# Create Hermes data directory.
RUN mkdir -p /root/.hermes

# Runtime bootstrap script.
COPY start.sh /usr/local/bin/hermes-container-start
RUN chmod +x /usr/local/bin/hermes-container-start

# Persistent data. Keep this mounted in EasyPanel.
VOLUME ["/root/.hermes"]

EXPOSE 3000 8080

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/usr/local/bin/hermes-container-start"]