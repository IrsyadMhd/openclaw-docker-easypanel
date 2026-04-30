# 🦞 OpenClaw — Deploy ke EasyPanel (ARM64)

## Konsep

Container ini bekerja seperti **VPS** — sudah terinstall `openclaw` (v4.26), `gog` (Google Suite CLI), `vim`, dan `rclone` secara global.
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

1. Buka tab **Terminal** di EasyPanel
2. Jalankan:
   ```bash
   openclaw onboard
   ```
3. Ikuti instruksi onboarding (setup Telegram bot, dll)
4. Sampai muncul pesan:
   ```
   Onboarding complete. Use the dashboard link above to control OpenClaw.
   ```
5. Jalankan perintah berikut untuk bersihkan config yang tidak kompatibel:
   ```bash
   openclaw doctor --fix
   ```

### Langkah 3 — Restart Container

> ⚠️ **PENTING**: Setelah onboarding selesai, **WAJIB restart container** agar gateway otomatis jalan.

1. Di EasyPanel → klik **Redeploy** atau **Restart** pada service OpenClaw
2. Setelah restart, gateway akan **otomatis berjalan** di background
3. Coba chat ke bot Telegram — seharusnya sudah merespons ✅

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
ps aux | grep openclaw
```

Jika ada proses `openclaw-gateway`, berarti sudah jalan. ✅

---

## Alur Ringkasan

```
Deploy Container
    ↓
Container Start → Gateway GAGAL (belum onboarding) → Container tetap hidup
    ↓
Buka Terminal → openclaw onboard
    ↓
Onboarding Selesai
    ↓
⚠️ RESTART Container di EasyPanel
    ↓
Container Start → Gateway BERHASIL (config sudah ada) ✅
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

# 3. Jalankan onboarding
openclaw onboard

# 4. Restart container setelah onboarding
docker restart openclaw

# 5. (Opsional) Setup rclone
vim /root/.config/rclone/rclone.conf
```

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
openclaw gateway --port 18789 &           # Jalankan gateway manual (jika perlu)
openclaw doctor                           # Diagnostik
npm install -g openclaw@2026.4.26         # Update ke versi spesifik (cara aman)
npm install -g openclaw@latest            # Update ke versi terbaru

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
| Bot Telegram tidak merespons | Pastikan gateway jalan: `ps aux \| grep openclaw`. Jika tidak ada, restart container atau jalankan `openclaw gateway &` |
| Container exit sendiri | Pastikan `restart: unless-stopped` aktif |
| Port tidak bisa diakses | Pastikan gateway bind ke `lan`: `openclaw gateway --port 18789 --bind lan &` |
| **CPU spike 100% saat chat** | Pastikan `OPENCLAW_NO_AUTO_UPDATE=1` ter-set. Cek log: `cat /root/.openclaw/gateway.log`. Jalankan `openclaw doctor --fix` |
| **RAM bengkak >1.5GB** | Verifikasi `NODE_OPTIONS=--max-old-space-size=1200` aktif: `echo $NODE_OPTIONS`. Nilai ideal ~60% dari RAM container |
| Config error setelah upgrade versi | Jalankan `openclaw doctor --fix` untuk auto-repair config yang tidak kompatibel |
| Perlu update openclaw | Masuk terminal → `npm install -g openclaw@2026.4.26` (atau `@latest`) |
| Cek log gateway | `cat /root/.openclaw/gateway.log` atau `tail -f /root/.openclaw/gateway.log` |
| Onboarding sudah selesai tapi gateway tidak jalan | **Restart container** di EasyPanel |
| Rclone config hilang setelah rebuild | Seharusnya tidak, karena disimpan di volume. Cek volume mount di EasyPanel |
| Rclone error "config not found" | Cek symlink: `ls -la /root/.config/rclone/` |
