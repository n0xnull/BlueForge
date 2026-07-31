# BlueForge — VM Runbook (Deploy Fresh & Fix Autostart)

> Dokumen ini khusus untuk VM Ubuntu di VMware yang sebelumnya punya instalasi lama
> (`abilithic-defensive-competition` / `/opt/abilithic-agent/`).
> Ikuti **urutan langkah**; jangan skip.

---

## Ringkasan

Instalasi lama menyebabkan kiosk tetap menampilkan nama/logo lama karena:
1. Systemd service lama (`/opt/abilithic-agent/`) masih jalan.
2. GNOME autostart (`.config/autostart/`) mungkin masih punya file lama.
3. Folder repo lama (`~/abilithic-defensive-competition`) masih ada di disk.

Solusi: stop & hapus semua yang lama, clone BlueForge fresh, install ulang.

---

## BAGIAN 1 — Bersihkan Instalasi Lama

```bash
# 1a. Stop dan disable service lama (kalau ada)
sudo systemctl stop abilithic-agent.service 2>/dev/null || true
sudo systemctl disable abilithic-agent.service 2>/dev/null || true
sudo systemctl stop blueforge-agent.service 2>/dev/null || true
sudo systemctl disable blueforge-agent.service 2>/dev/null || true

# 1b. Hapus unit file systemd lama
sudo rm -f /etc/systemd/system/abilithic-agent.service
sudo rm -f /etc/systemd/system/blueforge-agent.service
sudo systemctl daemon-reload

# 1c. Hapus folder instalasi lama
sudo rm -rf /opt/abilithic-agent
sudo rm -rf /opt/blueforge-agent

# 1d. Hapus GNOME autostart lama (file .desktop di autostart)
rm -f ~/.config/autostart/abilithic*.desktop
rm -f ~/.config/autostart/blueforge*.desktop
rm -f ~/.config/autostart/dhc*.desktop

# 1e. Hapus shortcut Desktop lama
rm -f ~/Desktop/restart-kiosk.desktop
rm -f ~/Desktop/abilithic*.desktop

# 1f. (Opsional) Hapus folder repo lama
# Ganti nama folder sesuai yang ada di VM kamu:
rm -rf ~/abilithic-defensive-competition
rm -rf ~/BlueForge    # akan di-clone ulang, jadi hapus dulu kalau ada yang stale
```

---

## BAGIAN 2 — Rename User (Opsional, Lakukan Sebelum Deploy)

> Skip bagian ini kalau nama user sudah benar atau tidak perlu diubah.

Tujuan: ganti user `cyber_sec` → `cyber`, display name → `BlueForge`.

```bash
# Login sebagai user lain / TTY root (Ctrl+Alt+F3), atau via sudo dari user lain
# JANGAN ganti nama user aktif yang sedang login GUI!

# 2a. Tambah user sementara dulu (kalau belum ada alternatif)
sudo adduser tempuser
sudo usermod -aG sudo tempuser

# 2b. Logout dari GUI, login ke TTY sebagai tempuser (Ctrl+Alt+F3)
# Atau gunakan sesi SSH.

# 2c. Rename user dan home folder
sudo usermod -l cyber cyber_sec
sudo usermod -d /home/cyber -m cyber
sudo groupmod -n cyber cyber_sec

# 2d. Ubah display name
sudo chfn -f "BlueForge" cyber

# 2e. Ganti password
sudo passwd cyber
# masukkan password baru: blueforge

# 2f. (Opsional) Hapus user sementara
sudo deluser --remove-home tempuser

# 2g. Login kembali sebagai cyber
```

---

## BAGIAN 3 — Clone BlueForge Fresh

```bash
# 3a. Pastikan git sudah terpasang
sudo apt-get install -y git

# 3b. Clone repo
cd ~
git clone https://github.com/n0xnull/BlueForge.git
cd ~/BlueForge

# 3c. Verifikasi struktur ada
ls agent/kiosk/install-kiosk.sh
ls agent/kiosk/blueforge.desktop
ls agent/kiosk/blueforge-icon.png
```

---

## BAGIAN 4 — Konfigurasi

```bash
# 4a. Salin config contoh
cp ~/BlueForge/agent/config.example.yaml ~/BlueForge/agent/config.yaml

# 4b. Edit URL portal
nano ~/BlueForge/agent/config.yaml
```

Isi yang perlu dicek/diubah:
```yaml
portal_url: "https://blueforge.vercel.app"   # ← URL Vercel production kamu
image_version: "2025.01"
poll_interval_sec: 15
local_ui_port: 9090
state_dir: "/var/lib/blueforge-agent"
log_level: "INFO"
```

Simpan: `Ctrl+O` → Enter → `Ctrl+X`

---

## BAGIAN 5 — Install Kiosk (Autostart + Deploy ke /opt)

```bash
cd ~/BlueForge
sudo bash agent/kiosk/install-kiosk.sh
```

Skrip ini otomatis:
- Install dependency Python (flask, requests, yaml)
- Salin agent ke `/opt/blueforge-agent/`
- Pasang GNOME autostart di `~/.config/autostart/blueforge.desktop`
- Taruh shortcut "Restart BlueForge" di Desktop

Setelah selesai, set URL portal di config yang sudah di-deploy:
```bash
sudo nano /opt/blueforge-agent/config.yaml
# pastikan portal_url sudah benar
```

---

## BAGIAN 6 — (Opsional) Install Systemd Service

Kalau ingin agen juga jalan sebagai systemd service (bukan hanya GNOME autostart):

```bash
sudo cp ~/BlueForge/agent/systemd/blueforge-agent.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable blueforge-agent.service
sudo systemctl start blueforge-agent.service

# Cek status
sudo systemctl status blueforge-agent.service
```

> **Catatan:** GNOME autostart (langkah 5) sudah cukup untuk mode kiosk biasa.
> Systemd service berguna kalau kamu ingin agent jalan sejak boot (sebelum login GUI).
> Jika keduanya aktif, pastikan port 9090 tidak konflik — matikan salah satu.

---

## BAGIAN 7 — Tanam Celah (Sebelum Lomba)

```bash
cd ~/BlueForge
sudo bash image/build/provision.sh
```

> **PENTING:** Langkah ini menanam celah keamanan yang akan dinilai selama lomba.
> Lakukan **setelah** kiosk terpasang dan config sudah benar.
> Script ini menggunakan nama internal `dhc-*` (tidak perlu diubah — itu nama
> teknis challenge, bukan nama brand yang terlihat peserta).

---

## BAGIAN 8 — Auto-Login Desktop (Opsional)

Agar peserta tidak perlu ketik password saat VM nyala:

```bash
sudo nano /etc/gdm3/custom.conf
```

Tambahkan/ubah pada bagian `[daemon]`:
```ini
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=cyber
```

Simpan lalu reboot:
```bash
sudo reboot
```

---

## BAGIAN 9 — Test Tanpa Reboot

```bash
# Jalankan kiosk manual (untuk uji cepat)
python3 /opt/blueforge-agent/kiosk.py

# Tekan Alt+F4 atau jalankan dari terminal lain untuk menutup:
pkill -f kiosk.py
```

Kiosk harus tampil dengan nama **BlueForge** dan logo yang benar.

---

## BAGIAN 10 — Verifikasi Akhir

Checklist sebelum distribusi ke peserta:

```bash
# ✅ Autostart terpasang
ls ~/.config/autostart/blueforge.desktop

# ✅ Agent ada di /opt
ls /opt/blueforge-agent/kiosk.py
ls /opt/blueforge-agent/config.yaml

# ✅ Config URL sudah benar
grep portal_url /opt/blueforge-agent/config.yaml

# ✅ Icon BlueForge terpasang
ls /opt/blueforge-agent/kiosk/blueforge-icon.png

# ✅ Tidak ada file/service lama
ls /opt/abilithic-agent 2>/dev/null && echo "⚠️ MASIH ADA folder lama!" || echo "✅ Bersih"
systemctl is-active abilithic-agent.service 2>/dev/null && echo "⚠️ Service lama masih jalan!" || echo "✅ Bersih"

# ✅ Uji kiosk
python3 /opt/blueforge-agent/kiosk.py
```

---

## Troubleshooting

| Masalah | Solusi |
|---|---|
| Kiosk masih tampil nama/logo lama | Pastikan `/opt/blueforge-agent/` sudah dari repo BlueForge terbaru (`git pull` lalu `install-kiosk.sh` lagi) |
| App tidak muncul saat boot | Cek `~/.config/autostart/blueforge.desktop` ada. Uji manual: `python3 /opt/blueforge-agent/kiosk.py` |
| Layar putih / "tidak bisa hubungi agent" | `portal_url` salah di config.yaml, atau agent belum siap — tunggu beberapa detik |
| Port 9090 sudah dipakai | Ada instance lain yang jalan. `sudo pkill -f "kiosk.py"` lalu coba lagi |
| pywebview error | Abaikan — otomatis fallback ke Firefox/Chromium kiosk mode |
| `install-kiosk.sh` gagal detect user | Jalankan dengan `sudo bash agent/kiosk/install-kiosk.sh` (harus ada `SUDO_USER`) |
| Service lama masih jalan di background | `sudo systemctl stop abilithic-agent && sudo systemctl disable abilithic-agent` |

---

*BlueForge · Defend. Harden. Compete. · docs/VM-RUNBOOK.md*
