# =============================================================================
# OpenClaw + OpenCRM durable ARM64 container for EasyPanel
# =============================================================================
# Purpose:
# - OpenClaw runtime
# - Bun toolchain for OpenCRM
# - PostgreSQL 15 + Redis 7 available inside the container
# - pgvector installed as PostgreSQL extension name: vector
# - Services auto-start on container restart
# - Important data paths declared as volumes
#
# Important durability note:
# - Dockerfile VOLUME declarations protect normal restarts and create Docker volumes.
# - For EasyPanel/container recreate/redeploy, bind or named volumes MUST be kept/mounted:
#     /root/.openclaw
#     /var/lib/postgresql
#     /var/lib/redis
# - Do not delete those volumes when redeploying, or DB/Redis/OpenClaw workspace data can be lost.
# =============================================================================

FROM --platform=linux/arm64 node:22-bookworm

ENV TZ=Asia/Jakarta \
    DEBIAN_FRONTEND=noninteractive \
    BUN_INSTALL=/root/.bun \
    PATH=/root/.bun/bin:/usr/lib/postgresql/15/bin:$PATH \
    POSTGRES_PASSWORD=opencrm_local_dev \
    OPENCRM_DB=opencrm_db \
    REDIS_BIND=127.0.0.1 \
    REDIS_PORT=6379

# Essential tools + PostgreSQL/Redis build/runtime dependencies.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
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
      build-essential \
      pkg-config \
      postgresql-15 \
      postgresql-server-dev-15 \
      postgresql-contrib-15 \
      redis-server \
      redis-tools \
      netcat-openbsd \
      lsb-release \
      tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Timezone.
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install pgvector from upstream source.
# PostgreSQL extension name is "vector", not "pgvector".
ARG PGVECTOR_VERSION=0.8.2
RUN set -eux; \
    cd /tmp; \
    curl -fsSL "https://github.com/pgvector/pgvector/archive/refs/tags/v${PGVECTOR_VERSION}.tar.gz" -o pgvector.tar.gz; \
    tar -xzf pgvector.tar.gz; \
    cd "pgvector-${PGVECTOR_VERSION}"; \
    make; \
    make install; \
    cd /; \
    rm -rf /tmp/pgvector-${PGVECTOR_VERSION} /tmp/pgvector.tar.gz

# Install Bun.
ARG BUN_VERSION=1.3.13
RUN curl -fsSL https://bun.sh/install | bash -s -- "bun-v${BUN_VERSION}" \
    && bun --version

# Install OpenClaw globally.
ARG OPENCLAW_VERSION=2026.4.15
RUN npm install -g "openclaw@${OPENCLAW_VERSION}"

# Python packages baked into image.
RUN pip3 install --break-system-packages mysql-connector-python

# Install gogcli (gog) — Google Suite CLI.
ARG TARGETARCH
ARG GOG_VERSION=0.12.0
RUN curl -fsSL "https://github.com/steipete/gogcli/releases/download/v${GOG_VERSION}/gogcli_${GOG_VERSION}_linux_${TARGETARCH}.tar.gz" \
      | tar -xz -C /usr/local/bin gog \
    && chmod +x /usr/local/bin/gog

# Create OpenClaw workspace and persistent config paths.
RUN mkdir -p /root/.openclaw/workspace /root/.openclaw/rclone /root/.config \
    && ln -sfn /root/.openclaw/rclone /root/.config/rclone \
    && touch /root/.openclaw/rclone/rclone.conf

# Ensure persistent PostgreSQL/Redis directories exist with correct ownership.
RUN mkdir -p /var/lib/postgresql /var/run/postgresql /var/lib/redis /var/log/redis /var/log/postgresql \
    && chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql /var/log/postgresql \
    && chown -R redis:redis /var/lib/redis /var/log/redis

# Runtime bootstrap script — copied from repo to avoid Docker BuildKit heredoc parse issues.
COPY start.sh /usr/local/bin/openclaw-container-start
RUN chmod +x /usr/local/bin/openclaw-container-start

# Persistent data. Keep these mounted in EasyPanel.
VOLUME ["/root/.openclaw", "/var/lib/postgresql", "/var/lib/redis"]

EXPOSE 18789 5432 6379

CMD ["/usr/local/bin/openclaw-container-start"]