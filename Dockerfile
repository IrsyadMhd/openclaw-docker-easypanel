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
RUN mkdir -p /var/lib/postgresql /var/run/postgresql /var/lib/redis /var/log/redis \
    && chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql \
    && chown -R redis:redis /var/lib/redis /var/log/redis

# Runtime bootstrap script.
RUN mkdir -p /var/log/postgresql && chown postgres:postgres /var/log/postgresql
RUN cat > /usr/local/bin/openclaw-container-start << 'EOF'
#!/usr/bin/env bash
# Note: Do NOT use set -e here. PostgreSQL/Redis startup errors must be handled
# per-function to prevent the container from aborting prematurely.

export PATH="/root/.bun/bin:/usr/lib/postgresql/15/bin:${PATH}"
export PGDATA="/var/lib/postgresql/15/main"
export PG_LOG="/var/log/postgresql/postgresql.log"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-opencrm_local_dev}"
export OPENCRM_DB="${OPENCRM_DB:-opencrm_db}"
export REDIS_BIND="${REDIS_BIND:-127.0.0.1}"
export REDIS_PORT="${REDIS_PORT:-6379}"

# Ensure all runtime dirs exist and have correct ownership
mkdir -p /root/.openclaw/workspace /root/.openclaw/rclone /root/.config
mkdir -p /var/run/postgresql /var/lib/postgresql /var/log/postgresql
mkdir -p /var/lib/redis /var/log/redis
ln -sfn /root/.openclaw/rclone /root/.config/rclone
chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql /var/log/postgresql
chown -R redis:redis /var/lib/redis /var/log/redis
touch "${PG_LOG}" && chown postgres:postgres "${PG_LOG}"

init_postgres() {
  if [ ! -s "${PGDATA}/PG_VERSION" ]; then
    echo "🐘 Initializing PostgreSQL data directory: ${PGDATA}"
    mkdir -p "${PGDATA}"
    chown -R postgres:postgres "${PGDATA}"
    if ! su -s /bin/bash postgres -c "initdb -D '${PGDATA}' --encoding=UTF8 --locale=C.UTF-8"; then
      echo "❌ initdb failed! Check permissions on ${PGDATA}"
      return 1
    fi
    cat >> "${PGDATA}/postgresql.conf" <<PGCONF
listen_addresses = '127.0.0.1'
port = 5432
shared_preload_libraries = ''
PGCONF
    cat >> "${PGDATA}/pg_hba.conf" <<PGHBA
host all all 127.0.0.1/32 md5
host all all ::1/128 md5
PGHBA
    chown -R postgres:postgres "${PGDATA}"
    echo "🐘 PostgreSQL data directory initialized."
  else
    echo "🐘 Existing data directory found at ${PGDATA}."
  fi
}

start_postgres() {
  if ! init_postgres; then
    echo "❌ Skipping PostgreSQL start due to init failure."
    return 1
  fi

  if pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
    echo "🐘 PostgreSQL already running."
  else
    echo "🐘 Starting PostgreSQL..."
    # -w = wait until server is ready before returning (critical fix)
    if ! su -s /bin/bash postgres -c "pg_ctl -D '${PGDATA}' -l '${PG_LOG}' -w -t 60 start"; then
      echo "❌ PostgreSQL failed to start. Last log lines:"
      tail -20 "${PG_LOG}" 2>/dev/null || echo "(no log found)"
      return 1
    fi
  fi

  echo "🐘 Waiting for PostgreSQL to accept connections..."
  for i in $(seq 1 30); do
    if pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
      echo "🐘 PostgreSQL is ready (attempt ${i}/30)."
      break
    fi
    sleep 1
  done

  echo "🐘 Ensuring postgres password, OpenCRM DB, and vector extension..."
  su -s /bin/bash postgres -c "psql -v ON_ERROR_STOP=1 --dbname=postgres -c \"ALTER USER postgres WITH PASSWORD '${POSTGRES_PASSWORD}';\"" || true
  su -s /bin/bash postgres -c "createdb '${OPENCRM_DB}'" 2>/dev/null || true
  su -s /bin/bash postgres -c "psql -v ON_ERROR_STOP=1 --dbname='${OPENCRM_DB}' -c 'CREATE EXTENSION IF NOT EXISTS vector;'" || true
  su -s /bin/bash postgres -c "psql -v ON_ERROR_STOP=1 --dbname='${OPENCRM_DB}' -c 'CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";'" || true
}

start_redis() {
  if redis-cli -h "${REDIS_BIND}" -p "${REDIS_PORT}" ping >/dev/null 2>&1; then
    echo "🔴 Redis already running."
    return
  fi

  echo "🔴 Starting Redis..."
  cat > /tmp/redis-openclaw.conf <<REDISCONF
bind ${REDIS_BIND}
port ${REDIS_PORT}
dir /var/lib/redis
dbfilename dump.rdb
appendonly yes
appendfilename "appendonly.aof"
supervised no
daemonize yes
logfile /var/log/redis/redis-server.log
REDISCONF
  chown redis:redis /tmp/redis-openclaw.conf
  su -s /bin/bash redis -c "redis-server /tmp/redis-openclaw.conf"
}

start_gateway() {
  echo "🦞 OpenClaw container started."
  if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -q ':18789'; then
    echo "⚠️  Gateway already running on port 18789, skipping..."
  else
    openclaw gateway --port 18789 >> /root/.openclaw/gateway.log 2>&1 &
    echo $! > /run/openclaw-gateway.pid
    echo "🦞 Gateway launched (PID: $!, logs: /root/.openclaw/gateway.log)"
  fi
}

start_postgres
start_redis
start_gateway

echo "✅ Runtime ready."
echo "   OpenCRM DB URL: postgresql://postgres:${POSTGRES_PASSWORD}@127.0.0.1:5432/${OPENCRM_DB}"
echo "   Redis URL: redis://127.0.0.1:${REDIS_PORT}"
echo "💡 First time? Run: openclaw onboard"

# Tail log files that exist; fall back to /dev/null to keep container alive
TAIL_FILES=()
[ -f "/root/.openclaw/gateway.log" ] && TAIL_FILES+=("/root/.openclaw/gateway.log")
[ -f "${PG_LOG}" ] && TAIL_FILES+=("${PG_LOG}")
[ -f "/var/log/redis/redis-server.log" ] && TAIL_FILES+=("/var/log/redis/redis-server.log")

if [ ${#TAIL_FILES[@]} -gt 0 ]; then
  tail -f "${TAIL_FILES[@]}" 2>/dev/null &
fi

# Keep container alive
tail -f /dev/null
EOF
RUN chmod +x /usr/local/bin/openclaw-container-start

# Persistent data. Keep these mounted in EasyPanel.
VOLUME ["/root/.openclaw", "/var/lib/postgresql", "/var/lib/redis"]

EXPOSE 18789 5432 6379

CMD ["/usr/local/bin/openclaw-container-start"]