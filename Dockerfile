# =============================================================================
# QwenPaw — Simple Container for ARM64 (EasyPanel)
# =============================================================================
# Konsep: Container berisi QwenPaw (personal AI assistant dari AgentScope).
# Setelah deploy, Console Web UI langsung bisa diakses di port 8088.
#
# Build:  docker build --platform linux/arm64 -t qwenpaw:arm64 .
# Run:    docker run -d --name qwenpaw -p 8088:8088 \
#           -v qwenpaw-data:/app/working \
#           -v qwenpaw-secrets:/app/working.secret \
#           qwenpaw:arm64
# Exec:   docker exec -it qwenpaw bash
# =============================================================================

FROM --platform=linux/arm64 python:3.12-slim-bookworm

# Install essential tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl \
      git \
      vim \
      procps \
      ca-certificates \
      tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set timezone to Asia/Jakarta (WIB)
ENV TZ=Asia/Jakarta
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# QwenPaw runtime env
ENV QWENPAW_WORKING_DIR=/app/working \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install QwenPaw (pinned for reproducible builds — bump via build-arg)
ARG QWENPAW_VERSION=1.1.3.post1
RUN pip install "qwenpaw==${QWENPAW_VERSION}"

# Persistent data directories
RUN mkdir -p /app/working /app/working.secret

WORKDIR /app

VOLUME ["/app/working", "/app/working.secret"]

EXPOSE 8088

# First run: initialize config with defaults (non-interactive).
# Subsequent runs: start straight into the app since config already exists.
CMD ["bash", "-c", "\
  echo '🐾 QwenPaw container started.'; \
  if [ ! -f /app/working/config.json ]; then \
    echo '🔧 First run — initializing QwenPaw config...'; \
    qwenpaw init --defaults --accept-security; \
  else \
    echo '✅ Config found at /app/working/config.json — skipping init.'; \
  fi; \
  echo '🚀 Starting QwenPaw app on 0.0.0.0:8088...'; \
  exec qwenpaw app --host 0.0.0.0 --port 8088 \
"]
