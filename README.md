# ⚕ Hermes Agent — Deploy ke EasyPanel (ARM64)

## Konsep

Container ini menjalankan **Hermes Agent** (AI agent by Nous Research) di ARM64.
Setelah deploy, masuk ke terminal dan jalankan `hermes setup` untuk konfigurasi awal.

> 💡 **Hermes Agent** adalah penerus OpenClaw dengan fitur yang jauh lebih kaya: self-improving skills, multi-platform messaging (Telegram, Discord, Slack, WhatsApp, Signal), browser automation, cron scheduling, subagent delegation, dan memory persisten lintas session.

---

## Deploy via EasyPanel UI

### Langkah 1 — Buat Service

1. Buka EasyPanel → **Create Service** → **App** → **GitHub**
2. Arahkan ke repo ini
3. **Dockerfile Path**: `Dockerfile`
4. **Volume**: mount `/root/.hermes` → agar data persistent (tidak hilang saat restart/rebuild)
5. **Port**:
   - `3000` → Hermes web dashboard
   - `8080` → Hermes gateway
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
Container Start → Hermes gateway start
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

## Tools yang Tersedia di Container

| Tool | Kegunaan |
|------|----------|
| `hermes` | AI agent — Telegram, Discord, Slack, WhatsApp, Signal, CLI |
| `vim` / `nano` | Text editor |
| `git` | Version control |
| `htop` | Monitor proses |
| `curl` | HTTP request |
| `rg` | ripgrep — fast file search |
| `ffmpeg` | Media processing (TTS voice messages) |

---

## Perintah Berguna

```bash
# Hermes Agent
hermes                                    # Interactive CLI chat
hermes setup                              # Setup wizard (pertama kali)
hermes model                              # Ganti LLM model/provider
hermes gateway setup                      # Setup messaging platform
hermes gateway start                      # Jalankan gateway
hermes gateway status                     # Cek status gateway
hermes tools                              # Konfigurasi tools
hermes doctor                             # Diagnostik
hermes update                             # Update ke versi terbaru
hermes claw migrate                       # Migrasi dari OpenClaw

# Hermes Slash Commands (dalam chat)
/new                                      # Conversation baru
/model openrouter:anthropic/claude-opus-4 # Ganti model
/skills                                   # List skills
/cron                                     # Buat scheduled task
/compress                                 # Kompres conversation
```

---

## Struktur Persistent Data

Semua data penting disimpan di volume `/root/.hermes/` agar survive rebuild:

```
/root/.hermes/
├── config.yaml               ← Hermes settings (model, tools, display)
├── .env                      ← API keys (OpenRouter, Telegram, dll)
├── auth.json                 ← OAuth tokens
├── memories/
│   ├── MEMORY.md             ← Agent memory
│   └── USER.md               ← User profile memory
├── skills/                   ← Skill documents
├── sessions/                 ← Session database
└── gateway.log               ← Log gateway
```

---

## Environment Variables

| Variable | Default | Deskripsi |
|----------|---------|-----------|
| `HERMES_HOME` | `/root/.hermes` | Data directory Hermes |

---

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| Bot Telegram tidak merespons | Cek gateway: `hermes gateway status`. Jika mati, restart container atau `hermes gateway start` |
| Container exit sendiri | Pastikan `restart: unless-stopped` aktif di EasyPanel |
| Hermes gagal start | Jalankan `hermes doctor` untuk diagnostik |
| Perlu update Hermes | Masuk terminal → `hermes update` |
| Cek log gateway | `cat /root/.hermes/gateway.log` |
| Setup sudah selesai tapi gateway tidak jalan | **Restart container** di EasyPanel |
| Migrasi dari OpenClaw | `hermes claw migrate --dry-run` untuk preview, lalu `hermes claw migrate` |
| Model/API key salah | `hermes model` untuk ganti model, edit `/root/.hermes/.env` untuk API keys |
