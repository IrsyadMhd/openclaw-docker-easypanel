# Panduan: Koneksi VSCode Lokal ke Docker Container di Easypanel (OCI)

> **Sistem:** Windows (PowerShell) → VPS Oracle Cloud (OCI) → Easypanel → Docker Container

---

## Prasyarat

- Akses ke OCI Console (https://cloud.oracle.com)
- Akses ke Easypanel dashboard
- VSCode terinstall di komputer lokal
- PowerShell di Windows

---

## Bagian 1: Membuat SSH Key Pair Baru di Windows

### Langkah 1 — Generate SSH Key

Buka PowerShell dan jalankan:

```powershell
ssh-keygen -t ed25519 -C "oci-vps"
```

Ketika muncul pertanyaan lokasi penyimpanan, tekan **Enter** untuk menggunakan lokasi default:
```
C:\Users\NamaUser\.ssh\id_ed25519
```

Ketika diminta passphrase, tekan **Enter** dua kali untuk tanpa passphrase.

### Langkah 2 — Tampilkan Public Key

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub
```

Output berupa satu baris panjang yang dimulai dengan `ssh-ed25519 AAAA...` — **copy seluruhnya**.

---

## Bagian 2: Menambahkan SSH Key ke Server via Easypanel Terminal

### Langkah 3 — Buka Terminal di Easypanel

1. Login ke Easypanel dashboard
2. Cari menu **Terminal** atau icon `>_` di server/service
3. Jalankan perintah berikut untuk mengecek user yang tersedia:

```bash
whoami
# Output: root
```

> **Catatan:** Meskipun terminal Easypanel berjalan sebagai `root`, OCI memblokir login SSH langsung sebagai root. SSH harus menggunakan user `ubuntu`.

### Langkah 4 — Tambahkan Public Key ke User Ubuntu

Di terminal Easypanel:

```bash
# Pastikan folder .ssh ada
ls /home/ubuntu/.ssh/

# Tambahkan public key (ganti dengan public key hasil Langkah 2)
echo "ssh-ed25519 AAAA...sampai...oci-vps" >> /home/ubuntu/.ssh/authorized_keys

# Set permission yang benar
chmod 700 /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

# Verifikasi — pastikan ada 2 baris (key lama + key baru)
cat /home/ubuntu/.ssh/authorized_keys
```

> **Penting:** Pastikan baris key baru **lengkap** dimulai dari `ssh-ed25519 AAAA` hingga akhir `oci-vps`. Kalau terpotong, hapus baris yang salah dan ulangi.

---

## Bagian 3: Test Koneksi SSH dari PowerShell

### Langkah 5 — Dapatkan IP Public Server

Buka OCI Console → **Compute → Instances** → klik instance → lihat **Public IP address**.

### Langkah 6 — Test Koneksi SSH

Di PowerShell:

```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519 ubuntu@IP_SERVER_KAMU
```

Ketika muncul pertanyaan verifikasi host pertama kali:
```
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
```

Jika berhasil, terminal akan masuk ke server Ubuntu.

### Langkah 7 — Tambahkan User Ubuntu ke Group Docker

Agar VSCode bisa mengakses Docker, jalankan di terminal SSH:

```bash
sudo usermod -aG docker ubuntu
```

Kemudian **logout dan login ulang** supaya perubahan group aktif:

```powershell
# Keluar dari SSH
exit

# Connect ulang
ssh -i $env:USERPROFILE\.ssh\id_ed25519 ubuntu@IP_SERVER_KAMU

# Verifikasi docker bisa diakses
docker ps
```

Jika `docker ps` menampilkan list container tanpa error, berarti berhasil.

---

## Bagian 4: Setup VSCode SSH Config

### Langkah 8 — Buat SSH Config File

Di PowerShell:

```powershell
notepad $env:USERPROFILE\.ssh\config
```

Isi dengan konfigurasi berikut, lalu **Save**:

```
Host oci-vps
    HostName IP_SERVER_KAMU
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
```

Ganti `IP_SERVER_KAMU` dengan IP public server OCI.

---

## Bagian 5: Koneksi VSCode ke Server via Remote SSH

### Langkah 9 — Install Ekstensi VSCode

Install dua ekstensi berikut di VSCode:

- **Remote - SSH** (ms-vscode-remote.remote-ssh)
- **Dev Containers** (ms-vscode-remote.remote-containers)

### Langkah 10 — Connect ke Server

1. Buka VSCode
2. Tekan `Ctrl+Shift+P`
3. Ketik **`Remote-SSH: Connect to Host`**
4. Pilih **`oci-vps`**
5. VSCode akan membuka window baru yang terhubung ke server

Indikator hijau di pojok kiri bawah VSCode akan berubah menjadi `SSH: oci-vps` jika berhasil.

---

## Bagian 6: Attach VSCode ke Docker Container

### Langkah 11 — Attach ke Container

1. Tekan `Ctrl+Shift+P`
2. Ketik **`Dev Containers: Attach to Running Container`**
3. Pilih container yang diinginkan (misalnya `openclaw_minimax...`)

VSCode akan membuka window baru yang terhubung langsung ke dalam container. Indikator di pojok kiri bawah akan berubah menjadi `Dev Container: nama-container`.

### Langkah 12 — Buka Folder Aplikasi di Dalam Container

Setelah attach, buka terminal di VSCode dengan `` Ctrl+` `` lalu cari folder aplikasi:

```bash
# Cek mount point untuk menemukan folder persistent
df -h
```

Cari baris yang menampilkan path seperti `/root/.openclaw` atau sejenisnya — itulah folder yang di-mount dari host dan bersifat **persistent**.

Buka folder tersebut di VSCode:

1. Tekan `Ctrl+Shift+P`
2. Ketik **`Open Folder`**
3. Masukkan path, contoh: `/root/.openclaw`
4. Klik **OK**

---

## Bagian 7: Menutup Koneksi

Setelah berhasil attach ke container dan membuka folder aplikasi:

- Window VSCode yang terhubung via **Remote-SSH ke server** sudah **tidak diperlukan** dan bisa ditutup.
- Cukup pertahankan window VSCode yang menampilkan **Dev Container** di pojok kiri bawah.

---

## Tips Tambahan

### Cek SSH Key yang Sudah Ada

Sebelum membuat key baru, cek apakah key lama masih ada:

```powershell
dir $env:USERPROFILE\.ssh
```

Jika ada file `id_rsa`, `id_ed25519`, atau `.pem` dari OCI, kemungkinan bisa langsung dipakai.

### Troubleshooting: Permission Denied

Jika SSH gagal dengan `Permission denied (publickey)`:

1. Cek isi `authorized_keys` di server — pastikan key baru lengkap (tidak terpotong)
2. Pastikan permission folder `.ssh` dan file `authorized_keys` sudah benar:
   ```bash
   chmod 700 /home/ubuntu/.ssh
   chmod 600 /home/ubuntu/.ssh/authorized_keys
   ```

### Troubleshooting: Docker Permission Error di VSCode

Jika muncul error `Current user does not have permission to run 'docker'`:

```bash
sudo usermod -aG docker ubuntu
```

Logout dan login ulang SSH, lalu coba lagi.

### Folder Persistent vs Non-Persistent di Container

| Lokasi | Persistent? | Keterangan |
|--------|-------------|------------|
| `/root/.openclaw` | ✅ Ya | Di-mount dari host, aman dari restart |
| `/usr/local/lib/node_modules/...` | ❌ Tidak | Di dalam layer container, hilang saat rebuild |

Selalu simpan file konfigurasi, skills, dan data penting di folder yang di-mount (cek dengan `df -h`).

---

*Dokumen ini dibuat berdasarkan pengalaman setup VPS Oracle Cloud (OCI) Ubuntu 22.04 dengan Easypanel dan Docker.*
