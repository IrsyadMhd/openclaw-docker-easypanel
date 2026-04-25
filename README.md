# 🐾 QwenPaw — Deploy ke EasyPanel (ARM64)

Container ringan untuk menjalankan [QwenPaw](https://qwenpaw.agentscope.io/) — personal AI assistant dari AgentScope — di VPS ARM64 via EasyPanel. Setelah deploy, buka Console Web UI di port `8088`, atur LLM provider & channel, lalu mulai chat.

---

## Konsep

- **Base image**: `python:3.12-slim-bookworm` (ARM64)
- **QwenPaw** diinstall via `pip install qwenpaw==1.1.4.post1`
- **Node.js 22 LTS** + ACP coding-agent CLIs ikut di-bake ke image → QwenPaw bisa langsung delegasi tugas coding ke external agent via fitur ACP-as-tool. Yang sudah pre-installed:
  - `@kilocode/cli` (`kilo`) + `kilo-acp` — untuk custom runner `kilo_code`.
  - `@anthropic-ai/claude-code` (`claude`) + `@zed-industries/claude-agent-acp` — untuk runner default `claude_code`.
  - `opencode-ai` (`opencode`) — untuk runner default `opencode`.
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
| `node` / `npm` / `npx` | Runtime Node.js 22 LTS — dipakai oleh Kilo Code CLI dan ACP runner berbasis npx (claude-agent-acp, codex-acp) |
| `kilo` | [Kilo Code CLI](https://kilo.ai/cli) — TUI coding agent (`kilo`, `kilo run "..."`, `kilo /connect`) |
| `kilo-acp` | ACP adapter Kilo Code — dipanggil QwenPaw untuk runner `kilo_code` |
| `claude` | [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) — TUI coding agent dari Anthropic |
| `claude-agent-acp` | ACP adapter Claude Code (`@zed-industries/claude-agent-acp`) — dipanggil QwenPaw untuk runner `claude_code` |
| `opencode` | [OpenCode](https://opencode.ai) — TUI coding agent open source. Dipakai langsung untuk runner `opencode` (`opencode acp`) |
| `vim` | Text editor |
| `git` | Version control (dipakai saat install skill dari GitHub) |
| `curl` | HTTP request |
| `htop` (via `procps`) | `ps`, `top` dasar |

Tidak ada `rclone`, `gog`, atau `gemini` — image sengaja dibuat minimal. Tambahkan sendiri via `apt-get` / `pip` / `npm` jika dibutuhkan skill tertentu.

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

## ACP — Delegasi Tugas Coding ke External Agent

Mulai QwenPaw v1.1.x ada built-in tool `delegate_external_agent` yang membiarkan bot QwenPaw "memanggil" coding agent lain (Kilo Code, Claude Code, OpenCode, Codex, Qwen Code) lewat ACP (Agent Client Protocol). Image ini sudah include Node.js + Kilo Code CLI supaya fitur tersebut langsung bisa dipakai.

### Kenapa bot awalnya bilang "tidak tahu apa itu ACP"

Tool `delegate_external_agent` **disabled by default** di toolkit setiap agent — jadi LLM literal tidak punya tool tersebut sebelum kamu aktifkan. Lihat [PR #3340](https://github.com/agentscope-ai/QwenPaw/pull/3340).

### Aktifkan tool di Console

1. Buka Console QwenPaw → pilih agent (mis. `default`).
2. Buka tab **Tools** / **Builtin Tools** → cari `delegate_external_agent` → toggle **enabled**.
3. Save → mulai sesi chat baru.

Alternatif: edit `agent.json` di `/app/working/agents/<agent_id>/agent.json` lalu restart container.

### Daftar runner default (sudah ter-konfigurasi di QwenPaw 1.1.4.post1)

Semua sudah `enabled: true` di `config.acp.agents`:

| Runner | Command yang dipanggil | Keterangan |
|--------|------------------------|------------|
| `opencode` | `opencode acp` | ✅ `opencode-ai` sudah pre-installed di image ini. Login provider via `opencode auth` di terminal. |
| `claude_code` | `npx -y @zed-industries/claude-agent-acp` | ✅ ACP adapter sudah pre-installed (npx tetap pakai versi global yang di-cache). Set env `ANTHROPIC_API_KEY`. |
| `codex` | `npx -y @zed-industries/codex-acp` | ⚠️ Belum pre-installed — npx akan download saat panggilan pertama. Set env `OPENAI_API_KEY`. Kalau mau pre-install, tambah `@zed-industries/codex-acp` di Dockerfile. |
| `qwen_code` | `qwen --acp` | ⚠️ Belum pre-installed — install manual dengan `npm i -g @qwen-code/qwen-code` di terminal container, atau tambahkan ke Dockerfile. |

### Tambahkan Kilo Code sebagai custom runner

Kilo Code belum termasuk default QwenPaw, jadi tambahkan manual ke `config.json`:

```jsonc
// /app/working/config.json
{
  "acp": {
    "agents": {
      "kilo_code": {
        "enabled": true,
        "command": "kilo-acp",
        "args": [],
        "trusted": true,
        "tool_parse_mode": "update_detail"
      }
    }
  }
}
```

Lalu **Restart** service. Field lain (opencode, qwen_code, claude_code, codex) tidak perlu disebut — QwenPaw akan auto-merge default-nya.

### Setup awal Kilo Code (sekali saja)

Kilo perlu di-authenticate ke provider model (OpenAI / Anthropic / Kilo Cloud / dll). Cara paling cepat — lewat terminal container:

```bash
# Masuk shell container (EasyPanel → Terminal, atau `docker exec -it qwenpaw bash`)
kilo
# Di TUI Kilo, ketik:
#   /connect
# → ikuti wizard untuk pilih provider & isi API key.
# Keluar dengan Ctrl+C → credential tersimpan di /root/.kilocode/ (volume tidak persistent!).
```

> ⚠️ **Penting**: `/root/.kilocode/` belum dimount sebagai volume. Setelah container redeploy, kredensial Kilo hilang dan harus `/connect` ulang. Workaround:
> - Tambahkan volume mount `/root/.kilocode` di EasyPanel.
> - Atau set env var Kilo (mis. `KILOCODE_API_KEY=...`, cek `kilo --help` versi terbaru).

Untuk runner lain, set env var di EasyPanel:

```bash
ANTHROPIC_API_KEY=sk-ant-...   # claude_code (langsung dipakai claude-agent-acp)
OPENAI_API_KEY=sk-...           # codex
DASHSCOPE_API_KEY=sk-...        # qwen_code
```

Untuk OpenCode, login provider lewat terminal container (kredensial disimpan di `~/.local/share/opencode/auth.json`):

```bash
docker exec -it qwenpaw bash
opencode auth login    # ikuti wizard pilih provider
```

> ⚠️ Sama seperti `~/.kilocode/`, direktori `~/.local/share/opencode/`, `~/.config/opencode/`, dan `~/.claude/` belum dimount sebagai volume. Mount manual di EasyPanel kalau mau persistent setelah redeploy. Lihat tabel volume di section [Pakai Custom Provider](#pakai-custom-provider-openai--anthropic-compatible).

### Pakai Custom Provider (OpenAI / Anthropic-compatible)

Semua coding agent CLI di image ini support endpoint pihak ketiga yang OpenAI-compatible (mis. Together AI, Groq, Perplexity, OpenRouter, LiteLLM, Ollama, LM Studio, MiniMax) atau Anthropic-compatible (mis. AWS Bedrock proxy, Z.ai, MiniMax). Setiap tool punya mekanisme sendiri — ringkasan:

#### Claude Code & `claude-agent-acp` — env var (paling simpel)

Kedua tool pakai Anthropic SDK resmi yang menghormati env var standar. Set di EasyPanel → Service → Environment:

```bash
ANTHROPIC_BASE_URL=https://your-provider.example.com/anthropic   # endpoint Anthropic-compat
ANTHROPIC_AUTH_TOKEN=<API_KEY_PROVIDER>                          # bukan ANTHROPIC_API_KEY
ANTHROPIC_MODEL=<model-id-yang-disediakan-provider>              # opsional, paksa model tertentu
```

Gunakan `ANTHROPIC_AUTH_TOKEN` (bukan `ANTHROPIC_API_KEY`) untuk third-party Anthropic-compat. `claude-agent-acp` di-spawn QwenPaw via `npx` dan mewarisi env container, jadi ACP delegasi otomatis kebaca env yang sama.

Verifikasi: `docker exec -it qwenpaw bash -lc 'claude -p "ping, jawab dengan satu kata"'`. Reference: <https://code.claude.com/docs/en/env-vars.md>.

#### Kilo Code — lewat `/connect` (atau edit `~/.kilocode/`)

Kilo tidak baca env var Anthropic / OpenAI standar. Konfigurasi lewat TUI:

```bash
docker exec -it qwenpaw bash
kilo            # masuk TUI
/connect        # pilih:
#   • "OpenAI Compatible" → isi Base URL, API Key, Model ID provider kamu
#   • "Anthropic"          → kalau provider-mu support endpoint Anthropic-compat
```

Kredensial tersimpan di `/root/.kilocode/`. **Mount path ini sebagai volume di EasyPanel** supaya tidak hilang saat redeploy. Reference: <https://kilo.ai/docs/ai-providers/openai-compatible>.

#### OpenCode — `opencode.json` + `{env:VAR_NAME}` placeholder (paling stateless)

Definisikan custom provider di `/root/.config/opencode/opencode.json` dan reference API key dari env var:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "my-openai-compat": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "My OpenAI-compatible Provider",
      "options": {
        "baseURL": "https://your-provider.example.com/v1",
        "apiKey": "{env:MY_PROVIDER_API_KEY}"
      },
      "models": {
        "model-id-1": { "name": "Model 1" },
        "model-id-2": { "name": "Model 2" }
      }
    }
  }
}
```

Untuk endpoint Anthropic-compat, ganti `npm` jadi `@ai-sdk/anthropic` dan tambah `baseURL` di `options`. Set env `MY_PROVIDER_API_KEY=...` di EasyPanel — tidak perlu file kredensial yang harus di-mount. Reference: <https://opencode.ai/docs/providers/>.

#### Volume mount yang disarankan

Karena Dockerfile ini hanya declare 2 volume default, tambahkan mount berikut di EasyPanel (Service → Volumes) supaya kredensial coding-agent persistent:

| Source / nama volume | Target di container | Untuk |
|---|---|---|
| `qwenpaw-data` | `/app/working` | (default) config QwenPaw |
| `qwenpaw-secrets` | `/app/working.secret` | (default) secret QwenPaw |
| `qwenpaw-kilo` | `/root/.kilocode` | Kilo Code provider config + sessions |
| `qwenpaw-claude` | `/root/.claude` | Claude Code settings (opsional kalau pakai env var) |
| `qwenpaw-opencode-cfg` | `/root/.config/opencode` | OpenCode config (`opencode.json`) |
| `qwenpaw-opencode-data` | `/root/.local/share/opencode` | OpenCode auth (`auth.json`) |

Kalau pakai pendekatan **env var + `{env:...}` placeholder** (Claude Code & OpenCode), 4 volume bawah opsional — tinggal Kilo yang wajib mount karena dia tidak baca env standar.

### Beri tahu bot kapan harus pakai

LLM tidak otomatis tahu kapan harus delegate. Tambahkan instruksi di `PROFILE.md` agent (`/app/working/agents/<agent_id>/PROFILE.md` atau lewat Console → Files):

```markdown
Kalau user minta bantuan ngoding (membuat/edit/menjelaskan kode, debug,
refactor, generate proyek), gunakan tool `delegate_external_agent` untuk
mendelegasikan tugas ke external coding agent.

Runner yang tersedia:
- `kilo_code`  — default untuk semua tugas coding (TUI Kilo Code, support 500+ model)
- `claude_code` — untuk reasoning kompleks / refactor besar
- `codex`       — untuk integrasi OpenAI
- `qwen_code`   — untuk task ringan & cepat
- `opencode`    — alternatif open-source

Protokol pakai:
  delegate_external_agent(action="start",   runner="kilo_code", message="<tugas detail>")
  delegate_external_agent(action="message", runner="kilo_code", message="<follow-up>")
  delegate_external_agent(action="respond", runner="kilo_code", message="<id-opsi-yang-diminta>")
  delegate_external_agent(action="close",   runner="kilo_code")

Selalu tutup sesi (`close`) setelah selesai supaya proses anak tidak menumpuk.
```

Save → mulai sesi chat baru → sekarang bot akan tahu cara pakai Kilo & teman-temannya.

### Verifikasi cepat dari terminal

```bash
node --version            # v22.x
npm --version
kilo --version            # Kilo Code CLI
which kilo-acp            # /usr/bin/kilo-acp atau /usr/lib/node_modules/...
claude --version          # Claude Code CLI dari Anthropic
which claude-agent-acp    # /usr/bin/claude-agent-acp
opencode --version        # OpenCode CLI
qwenpaw --version         # 1.1.4.post1
```

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
| Bot bilang tidak tahu ACP / tidak pakai coding tool | `delegate_external_agent` masih disabled — aktifkan di Console → Tools, lalu restart sesi chat. Lihat bagian [ACP](#acp--delegasi-tugas-coding-ke-external-agent). |
| `kilo: command not found` di terminal | Image lama tanpa Node/Kilo. Rebuild dari Dockerfile terbaru di branch `qwenpaw`. |
| `kilo /connect` butuh login berulang setelah redeploy | Mount `/root/.kilocode` sebagai volume di EasyPanel agar kredensial persistent. |
| `delegate_external_agent` error "command not found: kilo-acp" | Custom runner `kilo_code` belum ditambahkan ke `config.json` (lihat bagian ACP), atau `kilo-acp` tidak terinstall (rebuild image). |
| Claude Code error 401 / "Invalid API key" walau key di-set | Pakai `ANTHROPIC_AUTH_TOKEN` (bukan `ANTHROPIC_API_KEY`) untuk third-party Anthropic-compat provider. Cek juga `ANTHROPIC_BASE_URL` mengarah ke endpoint yang benar. |
| OpenCode tidak ketemu custom provider | Pastikan `opencode.json` ada di `/root/.config/opencode/opencode.json` dan field `npm` valid (`@ai-sdk/openai-compatible` atau `@ai-sdk/anthropic`). Restart container biar OpenCode reload config. |

---

## Lisensi & Kredit

- QwenPaw © AgentScope — https://github.com/agentscope-ai/QwenPaw
- Dockerfile & deploy recipe: IrsyadMhd
