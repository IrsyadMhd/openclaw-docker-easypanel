# 🦞 OpenClaw — Deploy ke EasyPanel (ARM64)

## Konsep

Container ini bekerja seperti **VPS** — sudah terinstall `openclaw` secara global. Tinggal masuk ke terminal dan jalankan `openclaw onboard`.

## Deploy via Docker Compose

```bash
# 1. Build & jalankan
docker compose -f docker-compose.easypanel.yml up -d

# 2. Masuk ke terminal container
docker exec -it openclaw bash

# 3. Jalankan onboarding
openclaw onboard
```

## Deploy via EasyPanel UI

1. **Buat Service** → App → GitHub → arahkan ke repo ini
2. **Dockerfile Path**: `Dockerfile.arm64`
3. **Port**: `18789`
4. **Volume**: mount `/root/.openclaw` untuk persistent storage
5. **Deploy**, tunggu build selesai
6. Buka **Terminal** di EasyPanel → ketik `openclaw onboard`

## Setelah Onboarding

Gateway otomatis berjalan. Akses Control UI di `http://<server-ip>:18789`.

## Perintah Berguna

```bash
openclaw onboard              # Setup awal
openclaw gateway --port 18789 --bind lan  # Jalankan gateway manual
openclaw doctor               # Diagnostik
openclaw update               # Update ke versi terbaru
```

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| Container exit sendiri | Pastikan `restart: unless-stopped` aktif |
| Port tidak bisa diakses | Pastikan gateway bind ke `lan`, bukan `localhost` |
| Perlu update openclaw | `docker exec -it openclaw npm install -g openclaw@latest` |
