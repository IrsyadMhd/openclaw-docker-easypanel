# 🦞 OpenClaw — Deploy ke EasyPanel (ARM64)

## Konsep

Container ini bekerja seperti **VPS** — sudah terinstall `openclaw` secara global.
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

### Setelah Restart — Verifikasi

Buka Terminal di EasyPanel, cek gateway berjalan:

```bash
ps aux | grep openclaw
```

Jika ada proses `openclaw gateway`, berarti sudah jalan. ✅

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
```

---

## Perintah Berguna

```bash
openclaw onboard                          # Setup awal (pertama kali)
openclaw gateway --port 18789 &           # Jalankan gateway manual (jika perlu)
openclaw doctor                           # Diagnostik
openclaw update                           # Update ke versi terbaru
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
