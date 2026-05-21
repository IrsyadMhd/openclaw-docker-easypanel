# ⚕ Hermes Agent v0.13.0 — Deploy ke EasyPanel (ARM64)

## Konsep

Container ini menjalankan **Hermes Agent v0.13.0** (AI agent by Nous Research) di ARM64.
Setelah deploy, masuk ke terminal dan jalankan `hermes setup` untuk konfigurasi awal.

> 💡 **Hermes Agent** adalah penerus OpenClaw dengan fitur yang jauh lebih kaya: self-improving skills, multi-platform messaging (Telegram, Discord, Slack, WhatsApp, Signal, Google Chat), browser automation, cron scheduling, subagent delegation, memory persisten lintas session, multi-agent kanban, dan video analysis.

> ⚠️ **v0.13.0 Breaking Changes**: Gateway sekarang berjalan sebagai non-root user `hermes` (UID 10000). Data path berubah ke `/opt/data`. Gateway port berubah dari `8080` ke `8642`.

---

## Deploy via EasyPanel UI

### Langkah 1 — Buat Service

1. Buka EasyPanel → **Create Service** → **App** → **GitHub**
2. Arahkan ke repo ini
3. **Dockerfile Path**: `Dockerfile`
4. **Volume**: mount `/opt/data` → agar data persistent (tidak hilang saat restart/rebuild)
5. **Port**:
   - `3000` → Hermes web dashboard
   - `8642` → Hermes gateway
6. Klik **Deploy**, tunggu build selesai

### Langkah 2 — Setup (Pertama Kali Saja)

1. Buka tab **Terminal** di EasyPanel
2. Jalankan:
   ```bash
   hermes setup
   ```
3. Ikuti instruksi setup:
   - Pilih LLM provider (OpenRouter, Nous Portal, OpenAI, Anthropic, dll)
   - Masukkan API key
   - Konfigurasi messaging platform (Telegram, Discord, dll)
4. Setelah selesai, setup gateway:
   ```bash
   hermes gateway setup
   ```

### Langkah 3 — Restart Container

> ⚠️ **PENTING**: Setelah setup selesai, **WAJIB restart container** agar gateway otomatis jalan.

1. Di EasyPanel → klik **Redeploy** atau **Restart** pada service
2. Setelah restart, gateway akan **otomatis berjalan** di background
3. Coba chat ke bot Telegram — seharusnya sudah merespons ✅

### Langkah 4 — Migrasi dari OpenClaw (Jika Applicable)

Jika sebelumnya menggunakan OpenClaw, Hermes bisa otomatis import data lama:

```bash
# Preview apa yang akan di-migrate
hermes claw migrate --dry-run

# Jalankan migrasi (import persona, memories, skills, API keys)
hermes claw migrate
```

Yang akan di-import:
- **SOUL.md** — persona file
- **Memories** — MEMORY.md dan USER.md
- **Skills** — user-created skills
- **API keys** — Telegram, OpenRouter, OpenAI, Anthropic, dll
- **Messaging settings** — platform configs, allowed users

### Setelah Restart — Verifikasi

Buka Terminal di EasyPanel, cek Hermes berjalan:

```bash
hermes doctor
hermes gateway status
```

---

## Alur Ringkasan

```
Deploy Container
    ↓
Container Start → Hermes gateway run (foreground, non-root)
    ↓
Buka Terminal → hermes setup
    ↓
Setup Selesai
    ↓
⚠️ RESTART Container di EasyPanel
    ↓
Container Start → Gateway BERHASIL (config sudah ada) ✅
    ↓
Bot Telegram/Discord aktif, siap digunakan 🎉
```

---

## Deploy via Docker Compose (Opsional)

```bash
# 1. Build & jalankan
docker compose up -d

# 2. Masuk ke terminal container
docker exec -it hermes-agent bash

# 3. Jalankan setup
hermes setup

# 4. Setup gateway
hermes gateway setup

# 5. Restart container setelah setup
docker restart hermes-agent
```

---

## Security (v0.13.0)

| Fitur | Detail |
|-------|--------|
| **Non-root user** | Gateway berjalan sebagai user `hermes` (UID 10000), bukan root |
| **Redaction** | Enabled by default — data sensitif otomatis di-redact dari log |
| **Platform security** | Discord role-allowlists, WhatsApp stranger rejection |
| **Override root** | Set `HERMES_ALLOW_ROOT_GATEWAY=1` jika perlu jalan sebagai root (tidak recommended) |

---

## Tools yang Tersedia di Container

| Tool | Kegunaan |
|------|----------|
| `hermes` | AI agent — Telegram, Discord, Slack, WhatsApp, Signal, Google Chat, CLI |
| `vim` / `nano` | Text editor |
| `git` | Version control |
| `htop` | Monitor proses |
| `curl` | HTTP request |
| `rg` | ripgrep — fast file search |
| `ffmpeg` | Media processing (TTS voice messages, video analysis) |

---

## Perintah Berguna

```bash
# Hermes Agent
hermes                                    # Interactive CLI chat
hermes setup                              # Setup wizard (pertama kali)
hermes model                              # Ganti LLM model/provider
hermes auth                               # Manage authentication (OAuth tokens)
hermes gateway setup                      # Setup messaging platform
hermes gateway run                        # Jalankan gateway (foreground, untuk Docker)
hermes gateway start                      # Jalankan gateway (background service)
hermes gateway status                     # Cek status gateway
hermes tools                              # Konfigurasi tools
hermes tools --add video                  # Aktifkan video analysis tool
hermes doctor                             # Diagnostik
hermes update                             # Update ke versi terbaru
hermes claw migrate                       # Migrasi dari OpenClaw

# Hermes Slash Commands (dalam chat)
/new                                      # Conversation baru
/goal                                     # Lock agent ke objective tertentu
/model openrouter:anthropic/claude-opus-4 # Ganti model
/skills                                   # List skills
/cron                                     # Buat scheduled task
/compress                                 # Kompres conversation
```

---

## Struktur Persistent Data

Semua data penting disimpan di volume `/opt/data/` agar survive rebuild:

```
/opt/data/
├── config.yaml               ← Hermes settings (model, tools, display)
├── .env                      ← API keys (OpenRouter, Telegram, dll)
├── auth.json                 ← OAuth tokens
├── memories/
│   ├── MEMORY.md             ← Agent memory
│   └── USER.md               ← User profile memory
├── skills/                   ← Skill documents
└── sessions/                 ← Session database
```

---

## Environment Variables

| Variable | Default | Deskripsi |
|----------|---------|-----------|
| `HERMES_HOME` | `/opt/data` | Data directory Hermes |
| `HERMES_ALLOW_ROOT_GATEWAY` | (unset) | Set `1` untuk izinkan gateway jalan sebagai root |
| `HERMES_DASHBOARD` | (unset) | Set `1` untuk aktifkan web dashboard di port 9119 |

---

## Fitur Baru di v0.13.0

| Fitur | Deskripsi |
|-------|-----------|
| **Multi-Agent Kanban** | Board kolaborasi multi-agent dengan heartbeat monitoring |
| **`/goal` command** | Lock agent ke objective tertentu, anti-drift |
| **Session durability** | Auto-resume session setelah restart/update |
| **Video analysis** | `video_analyze` tool (Gemini & multimodal models) |
| **Voice cloning** | xAI Custom Voices untuk TTS |
| **Google Chat** | Platform messaging ke-20 |
| **Checkpoints v2** | State persistence yang lebih reliable |
| **Pluggable providers** | Mudah integrasi model baru |
| **i18n** | 7 bahasa internasional |

---

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| Bot Telegram tidak merespons | Cek gateway: `hermes gateway status`. Jika mati, restart container atau `hermes gateway run` |
| Container exit sendiri | Pastikan `restart: unless-stopped` aktif di EasyPanel |
| Hermes gagal start | Jalankan `hermes doctor` untuk diagnostik |
| Gateway menolak start (root error) | v0.13.0 menolak root. Pastikan Dockerfile pakai `USER hermes`. Override: set `HERMES_ALLOW_ROOT_GATEWAY=1` |
| Perlu update Hermes | Masuk terminal → `hermes update` |
| Cek log gateway | Lihat log container di UI EasyPanel atau jalankan `docker logs hermes-agent` |
| Setup sudah selesai tapi gateway tidak jalan | **Restart container** di EasyPanel |
| Migrasi dari OpenClaw | `hermes claw migrate --dry-run` untuk preview, lalu `hermes claw migrate` |
| Model/API key salah | `hermes model` untuk ganti model, edit `/opt/data/.env` untuk API keys |
| Permission error pada volume | Pastikan volume mount ke `/opt/data` dan owned oleh UID 10000 |
