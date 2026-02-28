# 🦞 OpenClaw — Deploy ke EasyPanel (ARM64)

## Konsep

Container ini bekerja seperti **VPS** — sudah terinstall `openclaw`, `vim`, dan `rclone` secara global.
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
(Opsional) Setup rclone via vim
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
| `vim` | Text editor |
| `rclone` | Sync/transfer file ke cloud storage (GDrive, S3, dll) |
| `nano` | Text editor alternatif |
| `git` | Version control |
| `htop` | Monitor proses |
| `curl` | HTTP request |

---

## Perintah Berguna

```bash
openclaw onboard                          # Setup awal (pertama kali)
openclaw gateway --port 18789 &           # Jalankan gateway manual (jika perlu)
openclaw doctor                           # Diagnostik
openclaw update                           # Update ke versi terbaru
rclone lsd gdrive:                        # Test koneksi rclone
rclone copy gdrive:folder /local/path     # Copy file dari cloud
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

---

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| Bot Telegram tidak merespons | Pastikan gateway jalan: `ps aux \| grep openclaw`. Jika tidak ada, restart container atau jalankan `openclaw gateway &` |
| Container exit sendiri | Pastikan `restart: unless-stopped` aktif |
| Port tidak bisa diakses | Pastikan gateway bind ke `lan`: `openclaw gateway --port 18789 --bind lan &` |
| Perlu update openclaw | Masuk terminal → `npm install -g openclaw@latest` |
| Cek log gateway | `cat /root/.openclaw/gateway.log` |
| Onboarding sudah selesai tapi gateway tidak jalan | **Restart container** di EasyPanel |
| Rclone config hilang setelah rebuild | Seharusnya tidak, karena disimpan di volume. Cek volume mount di EasyPanel |
| Rclone error "config not found" | Cek symlink: `ls -la /root/.config/rclone/` |
