# 🦞 OpenClaw — Deploy ke EasyPanel (ARM64)

## Konsep

Container ini bekerja seperti **VPS** — sudah terinstall `openclaw` (v2026.9.3), `gog` (Google Suite CLI), `vim`, dan `rclone` secara global.
Runtime container menggunakan **Node.js 26** (direkomendasikan untuk OpenClaw 2026.9.3, dengan syarat minimum Node 24.16.0+).
Setelah deploy, masuk ke terminal dan jalankan `openclaw onboard` untuk setup awal.

---

## Deploy via EasyPanel UI

### Langkah 1 — Buat Service

1. Buka EasyPanel → **Create Service** → **App** → **GitHub**
2. Arahkan ke repo ini
3. **Dockerfile Path**: `Dockerfile`
4. **Volume**: mount `/root/.openclaw` → agar data persistent (tidak hilang saat restart/rebuild)
5. **Port**: ⚠️ **Tidak wajib** — hanya perlu jika ingin akses Control UI via web
   - Jika butuh: Published `18789`, Target `18789`, Protocol `TCP`
   - Jika tidak butuh akses web: **skip, jangan buat port**
6. Klik **Deploy**, tunggu build selesai

### Langkah 2 — Onboarding (Pertama Kali Saja)

> 💡 Pada start pertama, gateway yang dijalankan otomatis oleh container **akan gagal** dengan pesan `Missing config` di `gateway.log`. Ini normal karena onboarding belum dilakukan. Container tetap hidup.

1. Buka tab **Terminal** di EasyPanel
2. **Pastikan plugin GrowthCircle (`gc-provider`) sudah terpasang** — jika belum, pilihan provider GrowthCircle tidak akan muncul di wizard:
   ```bash
   openclaw plugins list
   # Jika gc-provider tidak ada di daftar:
   openclaw plugins install clawhub:gc-provider --accept-capabilities
   openclaw plugins list                     # verifikasi ulang
   openclaw plugins update gc-provider       # pastikan versi terbaru (v0.1.33+)
   ```
   > Install otomatis oleh container berjalan di background dan bisa gagal diam-diam saat start pertama, jadi selalu cek manual sebelum onboarding.
3. Jalankan:
   ```bash
   openclaw onboard
   ```
4. Ikuti instruksi onboarding (pilih provider AI, setup Telegram bot, dll)
5. Sampai muncul pesan:
   ```
   Onboarding complete. Use the dashboard link above to control OpenClaw.
   ```
6. Jalankan perintah berikut untuk bersihkan config yang tidak kompatibel:
   ```bash
   openclaw doctor --fix
   ```
7. **Tutup sesi onboard/TUI** (Ctrl+C / `exit`) sebelum lanjut. Proses `openclaw-onboard` atau `openclaw-tui` yang masih menggantung bisa menahan lock gateway.

### Langkah 3 — Restart Container

> ⚠️ **PENTING**: Setelah onboarding selesai, **WAJIB restart container** agar gateway otomatis jalan.

1. Di EasyPanel → klik **Redeploy** atau **Restart** pada service OpenClaw
2. Setelah restart, gateway akan **otomatis berjalan** di background

> ⚠️ **Container ini tidak memakai systemd.** Jangan gunakan `openclaw gateway restart`, `openclaw gateway stop`, atau `openclaw daemon install` — perintah itu butuh service manager. Untuk restart tanpa me-redeploy container:
> ```bash
> pkill -f openclaw
> sleep 2
> ps aux | grep -i openclaw | grep -v grep     # harus kosong
> nohup openclaw gateway --port 18789 >> /root/.openclaw/gateway.log 2>&1 &
> sleep 8
> tail -n 30 /root/.openclaw/gateway.log       # cari baris "[gateway] ready"
> ```
> `pkill` juga menutup sesi OpenClaw lain yang sedang terbuka (TUI, onboard).

### Langkah 3b — Aktifkan & Pairing Telegram

1. Cek status channel:
   ```bash
   openclaw channels status
   ```
   Status awal bisa `running, disconnected` — tunggu hingga ±2 menit (grace period koneksi channel) sampai `connected`.
2. Kirim pesan apa saja ke bot Telegram Anda. Jika bot membalas dengan **kode pairing**, setujui di terminal:
   ```bash
   openclaw pairing list telegram
   openclaw pairing approve telegram <KODE>
   ```
3. Coba chat lagi ke bot — seharusnya sudah merespons ✅
4. Jika tetap `disconnected`, cek log: `grep -i telegram /tmp/openclaw/openclaw-$(date +%F).log | tail -n 40` (biasanya token salah atau container tidak bisa mencapai `api.telegram.org`).

### Langkah 4 — Setup Rclone (Opsional)

Rclone sudah terinstall dan config file kosong sudah tersedia.
Config disimpan di volume persistent (`/root/.openclaw/rclone/`), jadi **tidak hilang** saat rebuild.

1. Buka Terminal di EasyPanel
2. Edit config:
   ```bash
   vim /root/.config/rclone/rclone.conf
   ```
3. Isi konfigurasi rclone, contoh:
   ```ini
   [gdrive]
   type = drive
   team_drive =
   token = {"access_token":"ya29.a0AT......."}
   ```
4. Simpan (`:wq`), lalu verifikasi:
   ```bash
   rclone lsd gdrive:
   ```

### Langkah 5 — Setup Gog CLI (Opsional)

[`gog`](https://github.com/steipete/gogcli) adalah CLI untuk Google Suite — Gmail, Calendar, Drive, Contacts, Sheets, Docs, dan lainnya. Sudah terinstall di container.

1. **Buat OAuth2 Credentials** di [Google Cloud Console](https://console.cloud.google.com/apis/credentials):
   - Buat project → Enable API yang dibutuhkan (Gmail, Drive, Calendar, dll)
   - Buat OAuth client (Desktop app) → Download JSON file

2. **Upload credentials** ke container (via rclone, scp, atau paste manual):
   ```bash
   # Simpan credentials
   gog auth credentials /path/to/client_secret_xxx.json
   ```

3. **Tambah akun Google** (headless/remote flow untuk server tanpa browser):
   ```bash
   # Manual flow — cocok untuk server tanpa browser
   gog auth add you@gmail.com --services user --manual
   # CLI akan print URL → buka di browser lokal → paste redirect URL kembali
   ```

4. **Test**:
   ```bash
   export GOG_ACCOUNT=you@gmail.com
   gog gmail labels list
   ```

> 💡 **Tips**: Gunakan `--manual` atau `--remote` flag saat `auth add`, karena container tidak punya browser.

### Setelah Restart — Verifikasi

Buka Terminal di EasyPanel, cek gateway berjalan:

```bash
ss -tlnp | grep 18789          # gateway listen di port 18789
openclaw channels status       # Telegram: enabled, configured, running, connected
openclaw plugins list          # gc-provider terpasang & enabled
```

Jika port 18789 listen dan Telegram `connected`, berarti sudah jalan. ✅

---

## Alur Ringkasan

```
Deploy Container
    ↓
Container Start → Gateway GAGAL "Missing config" (belum onboarding, normal) → Container tetap hidup
    ↓
Buka Terminal → openclaw plugins list (pastikan gc-provider ada, jika tidak: plugins install)
    ↓
openclaw onboard → openclaw doctor --fix → tutup sesi onboard/TUI
    ↓
⚠️ RESTART Container di EasyPanel
    ↓
Container Start → Gateway BERHASIL (config sudah ada) ✅
    ↓
openclaw channels status → Telegram connected → pairing approve (jika diminta)
    ↓
Bot Telegram aktif, siap digunakan 🎉
    ↓
(Opsional) Setup rclone, gog, dll via terminal
```

---

## Deploy via Docker Compose (Opsional)

```bash
# 1. Build & jalankan
docker compose up -d

# 2. Masuk ke terminal container
docker exec -it openclaw bash

# 3. Pastikan plugin gc-provider terpasang (install manual jika belum)
openclaw plugins list
openclaw plugins install clawhub:gc-provider --accept-capabilities

# 4. Jalankan onboarding
openclaw onboard

# 5. Restart container setelah onboarding
docker restart openclaw

# 6. (Opsional) Setup rclone
vim /root/.config/rclone/rclone.conf
```

> ⚠️ `docker-compose.yml` saat ini merujuk `Dockerfile.arm64` yang tidak ada di repo (yang tersedia hanya `Dockerfile`). Sesuaikan path `dockerfile:` sebelum memakai Docker Compose. Untuk EasyPanel gunakan `Dockerfile` langsung.

---

## Tools yang Tersedia di Container

| Tool | Kegunaan |
|------|----------|
| `openclaw` | AI assistant via Telegram |
| `gog` | [Google Suite CLI](https://github.com/steipete/gogcli) — Gmail, Calendar, Drive, Contacts, Sheets, Docs, dll |
| `gemini` | Google Gemini CLI — AI coding assistant |
| `vim` | Text editor |
| `rclone` | Sync/transfer file ke cloud storage (GDrive, S3, dll) |
| `nano` | Text editor alternatif |
| `git` | Version control |
| `htop` | Monitor proses |
| `curl` | HTTP request |

---

## Perintah Berguna

```bash
# OpenClaw
openclaw onboard                          # Setup awal (pertama kali)
openclaw doctor --fix                     # Bersihkan config lama (wajib setelah upgrade)
nohup openclaw gateway --port 18789 >> /root/.openclaw/gateway.log 2>&1 &   # Jalankan gateway manual (tanpa systemd)
pkill -f openclaw                         # Stop semua proses openclaw (pengganti "gateway restart/stop")
ss -tlnp | grep 18789                     # Cek gateway listen
openclaw doctor                           # Diagnostik
openclaw channels status                  # Status Telegram & channel lain
openclaw pairing list telegram            # Daftar permintaan pairing Telegram
openclaw pairing approve telegram <KODE>  # Setujui pairing
npm install -g openclaw@2026.9.3         # Update ke versi spesifik (cara aman)
npm install -g openclaw@latest            # Update ke versi terbaru

# Plugin Management (GrowthCircle / gc-provider, dll)
openclaw plugins list                     # Cek daftar & versi plugin terpasang
openclaw plugins install clawhub:gc-provider --accept-capabilities   # Install plugin GrowthCircle (jika belum ada)
openclaw plugins enable gc-provider --accept-capabilities            # Aktifkan jika terpasang tapi disabled
openclaw plugins update gc-provider       # Update plugin GrowthCircle ke versi terbaru (v0.1.33+)
openclaw plugins update --all             # Update seluruh plugin terpasang

# Monitor resource container
docker stats openclaw                     # Pantau CPU & RAM real-time
cat /root/.openclaw/gateway.log           # Cek log gateway

# Rclone
rclone lsd gdrive:                        # Test koneksi rclone
rclone copy gdrive:folder /local/path     # Copy file dari cloud

# Gog (Google Suite CLI)
gog --version                             # Cek versi
gog auth list                             # List akun yang tersimpan
gog gmail labels list                     # List label Gmail
gog gmail search "is:unread"              # Cari email
gog gmail send --to a@b.com --subject Hi  # Kirim email
gog calendar events                       # List event kalender
gog drive ls                              # List file di Google Drive
gog drive upload file.pdf                 # Upload file ke Drive
gog contacts search "John"                # Cari kontak
gog sheets read SPREADSHEET_ID            # Baca spreadsheet
```

---

## Struktur Persistent Data

Semua data penting disimpan di volume `/root/.openclaw/` agar survive rebuild:

```
/root/.openclaw/
├── rclone/
│   └── rclone.conf          ← Config rclone (symlink ke /root/.config/rclone/)
├── workspace/                ← Working directory openclaw
├── gateway.log               ← Log gateway
└── ... (config openclaw lainnya)
```

> 💡 **Gog config** disimpan di `~/.config/gog/`. Jika ingin persist, symlink ke volume:
> ```bash
> mkdir -p /root/.openclaw/gog
> ln -s /root/.openclaw/gog /root/.config/gog
> ```

---

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| Bot Telegram tidak merespons | Cek `ss -tlnp \| grep 18789` dan `openclaw channels status`. Jika gateway tidak jalan, restart container atau jalankan `nohup openclaw gateway --port 18789 >> /root/.openclaw/gateway.log 2>&1 &`. Jika bot membalas kode pairing: `openclaw pairing approve telegram <KODE>` |
| Pilihan GrowthCircle tidak muncul di wizard onboarding | Plugin `gc-provider` belum terpasang. Jalankan `openclaw plugins install clawhub:gc-provider --accept-capabilities`, cek `openclaw plugins list`, lalu ulangi `openclaw onboard` (atau `openclaw configure`) |
| `Plugin "gc-provider" requires capability consent` | Install/enable harus memakai flag `--accept-capabilities` (sudah otomatis di CMD container) |
| `Missing config. Run openclaw setup` di gateway.log | Normal sebelum onboarding selesai. Setelah onboarding, restart container |
| `another OpenClaw process owns gateway-lifecycle` | Ada proses openclaw lain (mis. onboard/TUI yang menggantung) yang menahan lock. Jalankan `pkill -f openclaw`, pastikan `ps aux \| grep -i openclaw` kosong, lalu jalankan gateway sekali dengan `nohup` |
| `Gateway: not detected (connect ECONNREFUSED 127.0.0.1:18789)` | Gateway belum jalan. Lihat `tail -n 50 /root/.openclaw/gateway.log`, lalu jalankan gateway dengan `nohup` (lihat Langkah 3) |
| `openclaw gateway restart/stop/install` error | Container tidak memakai systemd. Gunakan `pkill -f openclaw` + `nohup openclaw gateway ...` atau restart container di EasyPanel |
| Telegram `running, disconnected` | Tunggu ±2 menit (grace period). Jika tetap, cek `/tmp/openclaw/openclaw-<tanggal>.log` (token salah / tidak ada akses ke api.telegram.org) dan lakukan pairing |
| Warning "Gateway is binding to a non-loopback address" | Pastikan autentikasi gateway (token) sudah diset sebelum port 18789 dibuka ke publik |
| Container exit sendiri | Pastikan `restart: unless-stopped` aktif |
| Port tidak bisa diakses | Pastikan gateway bind ke `lan`: `openclaw gateway --port 18789 --bind lan &` |
| **CPU spike 100% saat chat** | Pastikan `OPENCLAW_NO_AUTO_UPDATE=1` ter-set. Cek log: `cat /root/.openclaw/gateway.log`. Jalankan `openclaw doctor --fix` |
| **RAM bengkak >1.5GB** | Verifikasi `NODE_OPTIONS=--max-old-space-size=1200` aktif: `echo $NODE_OPTIONS`. Nilai ideal ~60% dari RAM container |
| Config error setelah upgrade versi | Jalankan `openclaw doctor --fix` untuk auto-repair config yang tidak kompatibel |
| Perlu update openclaw | Masuk terminal → `npm install -g openclaw@2026.9.3` (atau `@latest`) |
| Runtime Node.js tidak kompatibel | OpenClaw 2026.9.3 butuh Node 24.16.0+ atau 26.1.0+ (Node 26 recommended). Node 22/23/25 tidak didukung. |
| Cek log gateway | `cat /root/.openclaw/gateway.log` atau `tail -f /root/.openclaw/gateway.log` |
| Onboarding sudah selesai tapi gateway tidak jalan | **Restart container** di EasyPanel |
| Rclone config hilang setelah rebuild | Seharusnya tidak, karena disimpan di volume. Cek volume mount di EasyPanel |
| Rclone error "config not found" | Cek symlink: `ls -la /root/.config/rclone/` |
