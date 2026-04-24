# 🐾 QwenPaw — Deploy ke EasyPanel (ARM64)

Container ringan untuk menjalankan [QwenPaw](https://qwenpaw.agentscope.io/) — personal AI assistant dari AgentScope — di VPS ARM64 via EasyPanel. Setelah deploy, buka Console Web UI di port `8088`, atur LLM provider & channel, lalu mulai chat.

---

## Konsep

- **Base image**: `python:3.12-slim-bookworm` (ARM64)
- **QwenPaw** diinstall via `pip install qwenpaw==1.1.3.post1`
- **Config & data persistent** di dua volume:
  - `/app/working` → config utama (`config.json`, agents, skills, workspaces, log)
  - `/app/working.secret` → file berisi secret (API key, token channel, dll)
- **First run** otomatis menjalankan `qwenpaw init --defaults --accept-security` → tidak perlu interaksi saat deploy pertama.
- **Subsequent runs** langsung menjalankan `qwenpaw app --host 0.0.0.0 --port 8088`.

---

## Deploy via EasyPanel UI

### Langkah 1 — Buat Service

1. Buka EasyPanel → **Create Service** → **App** → **GitHub**.
2. Arahkan ke repo ini.
3. **Dockerfile Path**: `Dockerfile`.
4. **Volume**: mount dua path agar data persistent:
   - `/app/working`
   - `/app/working.secret`
5. **Port**:
   - Published `8088`, Target `8088`, Protocol `TCP`.
   - Wajib jika ingin akses Console Web UI dari browser.
6. Klik **Deploy**, tunggu build selesai.

### Langkah 2 — Buka Console Web UI

Setelah container up, akses domain/port yang di-assign EasyPanel (mis. `https://qwenpaw.yourdomain.com` atau `http://<server-ip>:8088`).

Di Console:
1. **Configure LLM Provider** — masukkan API key (DashScope / OpenAI / Anthropic / dll).
2. **Enable Skills** yang dibutuhkan (`pdf`, `cron`, `file_reader`, `browser_cdp`, dll).
3. **Configure Channels** — pilih channel chat (DingTalk, Feishu, Discord, Telegram, WeChat, Console).
4. Test chat via tab Console di UI atau via channel yang sudah aktif.

### Langkah 3 — (Opsional) Set Environment Variables

Kalau ingin pass API key via env (lebih aman daripada di Console), set di EasyPanel → Service → Environment:

```bash
DASHSCOPE_API_KEY=sk-xxx
OPENAI_API_KEY=sk-xxx
ANTHROPIC_API_KEY=sk-xxx
GITHUB_TOKEN=ghp_xxx            # untuk import skill dari GitHub
QWENPAW_AUTH_ENABLED=true       # aktifkan auth Console (rekomendasi kalau expose ke publik)
QWENPAW_LOG_LEVEL=info
```

Restart service setelah set env.

---

## Deploy via Docker (di luar EasyPanel)

```bash
# Build untuk ARM64 (skip --platform kalau host-nya sudah arm64)
docker build --platform linux/arm64 -t qwenpaw:arm64 .

# Run dengan volume persistent
docker run -d \
  --name qwenpaw \
  --restart unless-stopped \
  -p 8088:8088 \
  -v qwenpaw-data:/app/working \
  -v qwenpaw-secrets:/app/working.secret \
  qwenpaw:arm64

# Masuk terminal container
docker exec -it qwenpaw bash
```

Buka `http://127.0.0.1:8088/` di browser.

---

## Tools yang Tersedia di Container

| Tool | Kegunaan |
|------|----------|
| `qwenpaw` | CLI QwenPaw (app, init, cron, skills, channels, agents) |
| `python3` / `pip` | Runtime Python |
| `vim` | Text editor |
| `git` | Version control (dipakai saat install skill dari GitHub) |
| `curl` | HTTP request |
| `htop` (via `procps`) | `ps`, `top` dasar |

Tidak ada `rclone`, `gog`, `gemini`, atau `node` — image sengaja dibuat minimal. Tambahkan sendiri via `apt-get` / `pip` jika dibutuhkan skill tertentu.

---

## Perintah Berguna

```bash
# Cek versi
qwenpaw --version

# Re-init config (hati-hati, --force akan overwrite)
qwenpaw init --defaults --force --accept-security

# List agents
qwenpaw agents list

# List & enable skills
qwenpaw skills list --agent-id default
qwenpaw skills config --agent-id default

# List & configure channels
qwenpaw channels list --agent-id default
qwenpaw channels config --agent-id default

# Cron jobs
qwenpaw cron list --agent-id default
qwenpaw cron create --agent-id default \
  --type text \
  --name "Daily Greeting" \
  --cron "0 9 * * *" \
  --channel console \
  --target-user "alice" \
  --target-session "session_001" \
  --text "Selamat pagi!"

# Send message ad-hoc lewat channel
qwenpaw channels send \
  --agent-id default \
  --channel console \
  --target-user alice \
  --target-session alice_session_001 \
  --text "Halo dari QwenPaw!"
```

---

## Struktur Persistent Data

Semua state di-persist lewat dua volume:

```
/app/working/                    ← volume qwenpaw-data
├── config.json                   # Config utama
├── HEARTBEAT.md                  # File heartbeat default agent
├── agents/                       # Per-agent config
├── workspaces/
│   └── default/
│       ├── skill.json            # Skill manifest per workspace
│       └── skills/               # Runtime skills aktif
└── skill_pool/                   # Shared skill repository

/app/working.secret/              ← volume qwenpaw-secrets
└── ...                           # API key, token channel, OAuth credentials
```

> 💡 Pisahkan dua volume agar data non-sensitif (`working`) bisa di-backup terpisah tanpa ikut expose secret.

---

## HTTP API (Ringkas)

Setelah container running, selain Console Web UI, semua kontrol bisa lewat REST API di `http://<host>:8088`:

```bash
# List agents
curl -s http://localhost:8088/api/agents

# Configure LLM provider
curl -X PUT http://localhost:8088/api/models/dashscope/config \
  -H "Content-Type: application/json" \
  -d '{"api_key": "sk-xxx"}'

# Set active model (global)
curl -X PUT http://localhost:8088/api/models/active \
  -H "Content-Type: application/json" \
  -d '{"provider_id": "dashscope", "model": "qwen-max", "scope": "global"}'

# Send message dari luar
curl -X POST http://localhost:8088/api/messages/send \
  -H "Content-Type: application/json" \
  -H "X-Agent-Id: default" \
  -d '{
    "channel": "console",
    "target_user": "alice",
    "target_session": "session_001",
    "text": "Hello from API!"
  }'
```

Docs lengkap: https://qwenpaw.agentscope.io/

---

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| Container exit setelah start | Cek log container: kemungkinan `pip install qwenpaw` gagal atau port 8088 bentrok. |
| Console tidak bisa dibuka dari browser | Pastikan port 8088 sudah di-publish di EasyPanel dan `qwenpaw app --host 0.0.0.0` (default di Dockerfile ini). |
| Config hilang saat rebuild | Pastikan volume `/app/working` dan `/app/working.secret` benar-benar di-mount di EasyPanel. |
| LLM request gagal | Cek API key di Console → Models, atau set env var `DASHSCOPE_API_KEY` / `OPENAI_API_KEY`. |
| Update QwenPaw ke versi terbaru | Edit `ARG QWENPAW_VERSION` di `Dockerfile`, atau pass `--build-arg QWENPAW_VERSION=x.y.z` saat build, lalu Redeploy di EasyPanel. |
| Install skill custom | Lewat Console UI → Skills Hub, atau `POST /api/skills/hub/install/start`. |
| Channel Telegram/Discord tidak terima pesan | Pastikan bot token benar, `enabled: true`, dan restart container setelah update config. |

---

## Lisensi & Kredit

- QwenPaw © AgentScope — https://github.com/agentscope-ai/QwenPaw
- Dockerfile & deploy recipe: IrsyadMhd
