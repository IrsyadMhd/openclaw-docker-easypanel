# =============================================================================
# Hermes Agent v0.13.0 — ARM64 container for EasyPanel
# =============================================================================
# Purpose:
# - Hermes Agent runtime (AI agent by Nous Research)
# - Built-in migration from OpenClaw via `hermes claw migrate`
# - Services auto-start on container restart
# - Important data paths declared as volumes
#
# Important durability note:
# - For EasyPanel/container recreate/redeploy, bind or named volumes MUST be kept/mounted:
#     /opt/data
# - Do not delete the volume when redeploying, or Hermes data can be lost.
#
# Security note (v0.13.0):
# - Gateway runs as non-root `hermes` user (UID 10000) by default.
# - Set HERMES_ALLOW_ROOT_GATEWAY=1 to override (not recommended).
# =============================================================================

FROM --platform=linux/arm64 node:22-bookworm

# ---------- Environment ----------
# VIRTUAL_ENV tells uv/pip/python which venv is active.
# PATH is prepended so `python3`, `hermes`, and all console_scripts
# resolve to the venv — not the system interpreter.
ENV TZ=Asia/Jakarta \
    DEBIAN_FRONTEND=noninteractive \
    VIRTUAL_ENV=/opt/hermes/.venv \
    PATH=/opt/hermes/.venv/bin:$PATH \
    HERMES_HOME=/opt/data \
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

# ---------- Install Hermes Agent from source ----------
# 1. Clone repo
# 2. Create a Python 3.11 venv at /opt/hermes/.venv
# 3. `uv sync` installs ALL deps + registers `hermes` console_script
#    into .venv/bin/hermes with a shebang pointing at .venv/bin/python3
# 4. npm install for Node.js components (TUI, web dashboard, etc.)
#
# Why `uv sync` instead of `uv pip install -e ".[all]"`:
#   - `uv sync` honours pyproject.toml [project.scripts] and creates
#     a proper console_script entry at .venv/bin/hermes whose shebang
#     is #!/opt/hermes/.venv/bin/python3 (absolute, unambiguous).
#   - `uv pip install -e ".[all]"` does NOT work because pyproject.toml
#     has no `all` extra — individual extras must be listed explicitly.
#   - The old `ln -sf /opt/hermes/hermes /usr/local/bin/hermes` symlinked
#     the raw launcher script whose `#!/usr/bin/env python3` shebang
#     resolved to the system Python (missing yaml, dotenv, etc.).
ARG HERMES_BRANCH=main
RUN git clone --depth=1 -b "${HERMES_BRANCH}" \
      https://github.com/NousResearch/hermes-agent.git /opt/hermes && \
    cd /opt/hermes && \
    uv venv .venv --python 3.11 && \
    uv sync --frozen --extra messaging --extra cli && \
    npm install --prefer-offline --no-audit && \
    npm cache clean --force

# Verify: .venv/bin/hermes must exist and its shebang must point to the
# venv python — not /usr/bin/python3.  Fail the build early if not.
RUN test -x /opt/hermes/.venv/bin/hermes && \
    head -1 /opt/hermes/.venv/bin/hermes | grep -q '/opt/hermes/.venv' && \
    echo "✅ hermes console_script installed correctly" || \
    (echo "❌ hermes console_script NOT found in .venv/bin — build failed" && exit 1)

# Create non-root hermes user (UID 10000) and data directory.
# v0.13.0 refuses to run gateway as root for security reasons.
RUN groupadd -g 10000 hermes && \
    useradd -u 10000 -g hermes -m -s /bin/bash hermes && \
    mkdir -p /opt/data && \
    chown -R hermes:hermes /opt/data /opt/hermes

# Runtime bootstrap script.
COPY start.sh /usr/local/bin/hermes-container-start
RUN chmod +x /usr/local/bin/hermes-container-start

# Persistent data. Keep this mounted in EasyPanel.
VOLUME ["/opt/data"]

EXPOSE 3000 8642

# Switch to non-root user.
USER hermes

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/usr/local/bin/hermes-container-start"]