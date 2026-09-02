# 🚀 Panduan Deployment BlueForge — Dari Nol Sampai Jalan

> Panduan lengkap untuk pemula. Ikuti **berurutan**. Estimasi total: **1,5–3 jam**
> (sebagian besar menunggu instalasi Ubuntu). Centang tiap langkah yang selesai. ✅

## Peta Perjalanan

```
[1] Push repo ke GitHub  ─┐
[2] Buat Supabase (DB)    ─┼─►  [3] Deploy Web ke Vercel ──► dapat URL publik
[4] Install Ubuntu di VM ─┘                                        │
                                                                   ▼
[5] Pasang Agent di VM (arahkan ke URL Vercel) + tanam celah
                                                                   ▼
[6] Uji: buat sesi → START → hardening → skor live → STOP  🎉
```

> 💡 **Tips hemat waktu:** instalasi Ubuntu (Langkah 4) makan waktu 20–40 menit.
> Kamu bisa **mulai Langkah 4 dulu** (biarkan menginstal di background), lalu kerjakan
> Langkah 1–3 sambil menunggu.

---

## ✅ Yang perlu disiapkan

- File `ubuntu-26.04-desktop-amd64.iso` (sudah kamu punya).
- Folder repo `BlueForge` (sudah dibuat).
- Koneksi internet.
- Akun email untuk daftar: **GitHub**, **Supabase**, **Vercel**, **Broadcom** (untuk VMware).

---
---

# LANGKAH 1 — Push Repo ke GitHub

Kita butuh repo online supaya (a) bisa di-deploy Vercel, dan (b) mudah di-clone ke dalam VM.

### 1.1 Install Git (jika belum)
- Windows: unduh dari **https://git-scm.com/download/win**, install (Next-Next-Finish).
- Cek berhasil: buka **Command Prompt / PowerShell**, ketik `git --version`.

### 1.2 Buat repo kosong di GitHub
1. Login ke **https://github.com** → klik **+** (kanan atas) → **New repository**.
2. Repository name: **`BlueForge`**.
3. Pilih **Private** (atau Public jika ingin open source). **Jangan** centang "Add README".
4. Klik **Create repository**. Biarkan halaman ini terbuka (ada perintah git-nya).

### 1.3 Push dari komputer kamu
Buka **PowerShell**, jalankan (ganti `<username>` dengan username GitHub kamu):
```powershell
cd "D:\Lab Kantor 2025\Github-Me\BlueForge"
git init
git add -A
git commit -m "feat: BlueForge v0.1"
git branch -M main
git remote add origin https://github.com/<username>/BlueForge.git
git push -u origin main
```
- Jika diminta login, ikuti proses autentikasi GitHub (browser/token).
- Selesai → refresh halaman GitHub, file-file kamu sudah muncul. ✅

> ⚠️ File `.env`, `config.yaml`, dan `*.ova` sudah otomatis **diabaikan** (`.gitignore`),
> jadi rahasia kamu tidak ikut ter-upload. Aman.

---
---

# LANGKAH 2 — Buat Database di Supabase

### 2.1 Daftar & buat project
1. Buka **https://supabase.com** → **Start your project** → daftar (paling cepat: **Continue with GitHub**).
2. Klik **New project**.
3. Isi:
   - **Name:** `blueforge`
   - **Database Password:** buat password kuat → **SIMPAN** (dicatat di tempat aman).
   - **Region:** pilih **Southeast Asia (Singapore)** (terdekat dari Indonesia).
4. Klik **Create new project**. Tunggu ±2 menit sampai project siap.

### 2.2 Jalankan schema database
1. Di menu kiri, klik **SQL Editor** → **+ New query**.
2. Buka file `db/schema.sql` di komputer, **copy seluruh isinya**, paste ke editor.
3. Klik **Run** (atau Ctrl+Enter). Pastikan muncul **Success**. ✅
4. Klik **+ New query** lagi. Buka `db/seed/difficulties.sql`, copy-paste, **Run**.
   Ini mengisi 3 tingkat lama (Easy/Medium/Hard, 15 check) + preset "fitcom"
   baru (30 check, dipakai lomba FITCOM). Kalau database sudah lama ada,
   jalankan dulu `db/migrations/0002_fitcom_preset.sql` sebelum seed ini. ✅

### 2.3 Ambil kunci API (penting untuk Langkah 3)
1. Menu kiri → **Project Settings** (ikon gerigi) → **API**.
2. Catat 3 nilai ini (nanti dipakai di Vercel):
   - **Project URL** → `https://xxxxx.supabase.co`
   - **anon public** key → (kunci publik)
   - **service_role** key → (kunci rahasia — **jangan sebar**)

### 2.4 (Opsional) Aktifkan Realtime untuk leaderboard instan
1. Menu kiri → **Database** → **Replication** (atau **Publications**).
2. Pada publication `supabase_realtime`, **tambahkan tabel `scores`**.
- Kalau langkah ini dilewati, leaderboard tetap update otomatis tiap ~4 detik (mode polling). Jadi tidak wajib.

---
---

# LANGKAH 3 — Deploy Web Portal ke Vercel

Vercel akan meng-host web (leaderboard + admin + API) di URL publik gratis, sehingga
agent di dalam VM bisa terhubung dari mana saja.

### 3.1 Siapkan dua nilai rahasia
Buat dua string acak dulu. Cara mudah (PowerShell, butuh Node.js — jika belum ada, lihat 3.5):
```powershell
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```
Jalankan **dua kali**, simpan hasilnya:
- Hasil ke-1 → untuk **AGENT_HMAC_SECRET**
- Hasil ke-2 (atau buat password sendiri) → untuk **ADMIN_PASSWORD** (password login halaman admin)

> Tanpa Node.js? Pakai string acak panjang apa pun (mis. dari password manager), minimal 32 karakter.

### 3.2 Import repo ke Vercel
1. Buka **https://vercel.com** → daftar/login (pilih **Continue with GitHub**).
2. **Add New… → Project** → pilih repo **BlueForge** → **Import**.

### 3.3 Atur Root Directory
- Di halaman konfigurasi, cari **Root Directory** → klik **Edit** → pilih folder **`web`**.
  (Penting! Karena kode web ada di subfolder `web/`.)

### 3.4 Isi Environment Variables
Masih di halaman yang sama, buka **Environment Variables**, tambahkan 5 baris berikut
(Name → Value):

| Name | Value |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Project URL dari Supabase (2.3) |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | anon public key (2.3) |
| `SUPABASE_SERVICE_ROLE_KEY` | service_role key (2.3) |
| `AGENT_HMAC_SECRET` | hasil acak ke-1 (3.1) |
| `ADMIN_PASSWORD` | password admin pilihanmu (3.1) |

Lalu klik **Deploy**. Tunggu ±1–2 menit sampai muncul **"Congratulations"**. ✅

### 3.5 Dapatkan URL & tes
- Vercel memberi URL seperti **`https://blueforge.vercel.app`**.
  **Catat URL ini** — nanti dimasukkan ke config agent.
- Buka URL tersebut → muncul halaman **leaderboard** ("Belum ada sesi aktif"). ✅
- Buka **`URL/admin`** → masukkan **ADMIN_PASSWORD** → berhasil masuk = web & database tersambung. 🎉

> 🧪 **(Opsional) Menjalankan web lokal untuk ngoprek:** install **Node.js LTS** dari
> https://nodejs.org → di folder `web/` jalankan `npm install`, buat file `.env.local`
> (salin dari `.env.example`, isi 5 nilai di atas), lalu `npm run dev` → buka `http://localhost:3000`.

---
---

# LANGKAH 4 — Install Ubuntu 26.04 di VMware

### 4.1 Unduh & install VMware Workstation Pro (gratis untuk personal)
VMware Workstation Pro kini **gratis untuk penggunaan pribadi**, tapi unduhnya lewat akun Broadcom:
1. Buat akun gratis di **https://www.broadcom.com** (Register).
2. Login → **Broadcom Support Portal** → cari **"VMware Workstation Pro"** → pilih versi terbaru (mis. **26H1**) untuk **Windows** → setujui Terms → **Download**.
3. Install file `.exe` (Next-Next-Finish). Saat ditanya lisensi, pilih **"Use for Personal Use / free"** (tanpa kunci).

> 🔁 **Alternatif lebih mudah:** kalau ribet dengan akun Broadcom, pakai **VirtualBox**
> (https://www.virtualbox.org) — gratis tanpa akun. Langkah membuat VM mirip. Panduan
> di bawah memakai VMware, tapi konsepnya sama di VirtualBox.

### 4.2 Buat Virtual Machine baru
1. Buka VMware → **Create a New Virtual Machine**.
2. Pilih **Installer disc image file (iso)** → **Browse** → pilih `ubuntu-26.04-desktop-amd64.iso`.
   - Jika VMware menawarkan **Easy Install**, isi nama, username, dan password → ini akan meng-install Ubuntu otomatis. (Boleh dipakai; kalau tidak muncul, lanjut manual.)
3. **Nama VM:** `blueforge-ubuntu` → pilih lokasi penyimpanan.
4. **Disk size:** **35 GB** (Desktop butuh ruang) → "Store as a single file".
5. **Customize Hardware:**
   - **Memory:** **4096 MB** (4 GB) minimal — Desktop 26.04 cukup berat.
   - **Processors:** 2.
   - **Network Adapter:** **NAT** (default, cocok agar VM punya internet via host).
6. **Finish** → VM akan menyala dan boot ke installer Ubuntu.

### 4.3 Install Ubuntu (jika bukan Easy Install)
Ikuti wizard installer Ubuntu:
1. Pilih bahasa → **Install Ubuntu**.
2. Keyboard: **English (US)** (atau sesuai).
3. **Normal installation** → boleh centang "Download updates".
4. **Erase disk and install Ubuntu** (aman, ini disk virtual, bukan disk asli kamu).
5. Zona waktu: **Jakarta**.
6. Buat akun:
   - **Nama:** bebas, **username:** mis. `student`, **password:** mis. `student123` (ingat baik-baik).
7. Klik **Install** → tunggu 15–30 menit → **Restart Now** → tekan Enter bila diminta.
8. Login ke desktop Ubuntu. ✅

### 4.4 Pasang VMware Tools (agar mulus)
Di terminal Ubuntu (buka "Terminal" dari menu aplikasi):
```bash
sudo apt update
sudo apt install -y open-vm-tools open-vm-tools-desktop
```
Ini memungkinkan copy-paste & resize layar. Reboot bila perlu.

---
---

# LANGKAH 5 — Pasang Agent di dalam VM

Semua perintah di bawah dijalankan **di Terminal Ubuntu (di dalam VM)**.

### 5.1 Install prasyarat
```bash
sudo apt update
sudo apt install -y git python3-pip openssh-server
```
> `openssh-server` dipasang agar celah SSH bisa ditanam & dicek (Desktop tak punya SSH bawaan).

### 5.2 Ambil kode agent
Clone repo kamu (ganti `<username>`; jika repo Private, masukkan token saat diminta):
```bash
cd ~
git clone https://github.com/n0xnull/BlueForge.git
cd BlueForge/agent
```
> Repo Private & susah login? Alternatif: di web GitHub, **Code → Download ZIP**, lalu
> pindahkan ke VM lewat drag-drop (butuh VMware Tools) atau shared folder, dan extract.

### 5.3 Install dependency Python agent
```bash
pip3 install -r requirements.txt --break-system-packages
```
(Jika `--break-system-packages` error/ tidak dikenal, jalankan tanpa flag itu.)

### 5.4 Konfigurasi agent → arahkan ke URL Vercel
```bash
cp config.example.yaml config.yaml
nano config.yaml
```
Ubah baris `portal_url` menjadi URL Vercel kamu (Langkah 3.5), contoh:
```yaml
portal_url: "https://blueforge.vercel.app"
image_version: "2026.04"
```
Simpan di nano: **Ctrl+O → Enter → Ctrl+X**.

### 5.5 Tanam celah keamanan (canonical dirty state)
Agar ada yang bisa di-hardening, jalankan skrip penanam celah:
```bash
cd ~/BlueForge
sudo bash image/build/provision.sh
```
Ini akan (sengaja) menanam **30 celah keamanan** (root login SSH aktif, UFW mati,
telnet terpasang, user rogue, permission longgar, backdoor SUID, dst. — lihat
`image/build/provision.sh`). Tingkat kesulitan yang dipilih nanti di admin
(Easy/Medium/Hard) menentukan subset mana yang benar-benar dinilai. ✅

### 5.6 Jalankan agent
```bash
cd ~/BlueForge/agent
sudo python3 main.py
```
- Biarkan terminal ini terbuka (agent berjalan di sini).
- Buka browser **di dalam VM** ke **http://localhost:9090** → muncul halaman registrasi agent. ✅

> 🛠️ **(Opsional) Jadikan service otomatis** (agar jalan saat boot):
> ```bash
> sudo mkdir -p /opt/blueforge-agent
> sudo cp -r ~/BlueForge/agent/* /opt/blueforge-agent/
> sudo cp /opt/blueforge-agent/systemd/blueforge-agent.service /etc/systemd/system/
> sudo systemctl daemon-reload && sudo systemctl enable --now blueforge-agent
> ```

---
---

# LANGKAH 6 — Uji End-to-End 🎉

### 6.1 Buat sesi (sebagai panitia/admin)
1. Di komputer host, buka **`URL-Vercel/admin`** → login dengan **ADMIN_PASSWORD**.
2. Isi nama lomba (mis. "Uji Coba #1"), pilih tingkat **Mudah (Easy)** → **+ Buat Sesi**.
3. Muncul **Kode Sesi**, contoh `BF-7Q2X`. **Catat.**

### 6.2 Registrasi peserta (di dalam VM)
1. Di VM, buka **http://localhost:9090**.
2. Isi Nama, Sekolah, dan **Kode Sesi** tadi → **Daftar**.
3. Muncul "Berhasil terdaftar. Menunggu START...". ✅
4. Cek: di halaman **admin** & **leaderboard**, nama peserta muncul.

### 6.3 START & hardening
1. Di **/admin**, klik **▶ Start** pada sesi. Timer mulai berjalan.
2. Di VM (`localhost:9090`), status berubah **RUNNING**, muncul daftar tugas
   hardening (jumlahnya sesuai tingkat: 6 di Easy, 11 di Medium, 15 di Hard).
3. Lakukan perbaikan di terminal VM, contoh:
   ```bash
   sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && sudo systemctl restart ssh
   sudo ufw --force enable
   sudo systemctl disable --now inetd 2>/dev/null; sudo apt -y purge telnetd 2>/dev/null
   sudo deluser --remove-home hacker
   sudo chmod 640 /etc/shadow
   ```
4. Dalam beberapa detik, **skor naik otomatis** dan tampil **live** di leaderboard (buka URL-Vercel di host). ✅

### 6.4 STOP
1. Di **/admin**, klik **⏹ Stop**. Skor **dibekukan**.
2. Perbaikan setelah STOP tidak menambah skor. Selesai! 🎉

Kalau semua ini berhasil, **v0.1 kamu resmi jalan end-to-end.** 🚀

---
---

# 🧯 Troubleshooting

## Cara Run — Ringkasan Cepat

### CARA RUN AWAL (VM baru/template baru saja di-clone)
```bash
# Hapus history terminal (VM clone jangan bocorkan command user sebelumnya)
cat /dev/null > ~/.bash_history && history -c && history -w

# Build soal (tanam 30 celah keamanan) di VM
cd ~/BlueForge
git pull
sudo bash image/build/provision.sh
```

### Update kode GitHub di VM yang SUDAH terpasang kiosk-nya
Ini bagian yang paling sering kelewat: kiosk/agent yang benar-benar jalan
saat boot itu **salinan terpisah** di `/opt/blueforge-agent/` (disalin oleh
`install-kiosk.sh` sekali saat instalasi awal) — **bukan** langsung dari
folder git ini. `git pull` saja **tidak cukup**, harus disusul resync ke `/opt`:
```bash
cd ~/BlueForge
git pull
sudo bash agent/kiosk/install-kiosk.sh    # resync kode ke /opt + pasang ulang shortcut/icon
sudo systemctl restart blueforge-agent    # restart service agent (systemd)

# uji tanpa reboot dulu:
sudo pkill -f kiosk.py 2>/dev/null
python3 /opt/blueforge-agent/kiosk.py     # Ctrl+C untuk berhenti setelah yakin OK

# baru reboot VM untuk pastikan autostart-nya juga ambil kode baru
```
> Verifikasi cepat apakah `/opt` sudah sinkron dengan repo:
> `diff ~/BlueForge/agent/kiosk.py /opt/blueforge-agent/kiosk.py`
> — kosong/tidak ada output berarti sudah sama persis.

### Kalau window kiosk tidak sengaja tertutup peserta
Sejak v0.3, `kiosk.py` **otomatis membuka lagi jendelanya sendiri** dalam
~2 detik kalau tertutup (baik ke-klik close, Alt+F4, dsb.) — peserta atau
panitia **tidak perlu melakukan apa pun**. Kalau suatu saat window tetap
tidak muncul lagi (kasus langka: proses kiosk.py ikut mati, bukan cuma
window-nya), ada dua fallback:
- **Peserta:** double-click shortcut **"Restart BlueForge"** di Desktop —
  tidak perlu buka terminal.
- **Panitia (lewat terminal/SSH):**
  ```bash
  bash /opt/blueforge-agent/kiosk/restart-kiosk.sh
  ```

## Command Troubleshooting Umum

```bash
# Status service inti (agent & telnet listener simulasi)
systemctl status blueforge-agent dhc-telnetd

# Apakah kiosk.py & main.py benar-benar jalan?
ps aux | grep -E "kiosk.py|main.py" | grep -v grep

# Log autostart kiosk (boot saat ini)
journalctl --user -b | grep -i -E "kiosk|webview|gtk"

# Log service agent (systemd, root)
sudo journalctl -u blueforge-agent -n 100 --no-pager

# Cek /opt sudah sinkron dengan repo git (kosong = sudah sama)
diff ~/BlueForge/agent/kiosk.py /opt/blueforge-agent/kiosk.py

# Restart paksa semuanya dari nol (kiosk + agent service)
sudo systemctl restart blueforge-agent
sudo pkill -f kiosk.py 2>/dev/null
python3 /opt/blueforge-agent/kiosk.py &

# Cek koneksi ke web portal (Vercel) dari dalam VM
curl -sS -o /dev/null -w "%{http_code}\n" "$(grep portal_url /opt/blueforge-agent/config.yaml | awk '{print $2}' | tr -d '\"')"
```

## Tabel Gejala → Solusi

| Gejala | Solusi |
|---|---|
| `localhost:9090` tak terbuka di VM | Pastikan `blueforge-agent.service` jalan (`systemctl status blueforge-agent`) atau terminal `sudo python3 main.py` masih jalan tanpa error. |
| Sudah `git pull` tapi perilaku VM tidak berubah | **Penyebab paling umum**: lupa resync ke `/opt/blueforge-agent/`. Jalankan `sudo bash agent/kiosk/install-kiosk.sh` lalu `sudo systemctl restart blueforge-agent`. |
| Kiosk blank/hitam setelah restart VM | Cek `ps aux \| grep kiosk.py` — kalau prosesnya tidak ada sama sekali, autostart gagal ke-trigger (cek `~/.config/autostart/blueforge.desktop` & `journalctl --user -b`). Kalau proses ADA tapi window tetap blank, coba paksa X11: edit `blueforge.desktop`, tambahkan `Environment=GDK_BACKEND=x11` sebelum `Exec=`. |
| Window kiosk ke-close peserta | Otomatis terbuka lagi ~2 detik. Kalau tidak, double-click shortcut **"Restart BlueForge"** di Desktop. |
| Registrasi: "kode sesi tidak ditemukan" | Pastikan sesi sudah dibuat di /admin & kode diketik benar (huruf besar). |
| Registrasi gagal / timeout | Cek `portal_url` di `config.yaml` (dan di `/opt/blueforge-agent/config.yaml`!) = URL Vercel yang benar (pakai `https://`). Cek VM ada internet (`ping google.com`). |
| Skor tidak naik | Perbaikan mungkin belum sesuai — lihat hint di `localhost:9090` (klik baris soal). Pastikan status **RUNNING**. |
| Leaderboard tak update | Tunggu ~4 detik (mode polling) atau aktifkan Realtime (2.4). Refresh halaman. |
| Admin "Password salah" | `ADMIN_PASSWORD` di Vercel ≠ yang kamu ketik. Cek Environment Variables di Vercel → Redeploy bila baru diubah. |
| Error 401 di agent | `AGENT_HMAC_SECRET` di Vercel berubah setelah peserta daftar. Daftar ulang peserta. |
| `pip3 install` error "externally managed" | Tambahkan `--break-system-packages`. |
| VMware minta lisensi | Pilih opsi **Personal Use (free)**, tanpa kunci. |
| Ubuntu berat/lemot | Naikkan RAM VM ke 4–6 GB, Processors ke 2–4 (VM Settings). |

---

# 📦 (Opsional) Setelah berhasil: buat OVA untuk peserta

Untuk lomba nyata, kamu bekukan VM ini menjadi 1 image yang dibagikan ke semua peserta:
1. Di VM, pastikan agent ter-install sebagai **service** (5.6 opsional) & `provision.sh` sudah dijalankan.
2. Matikan VM. Di VMware: **File → Export to OVF/OVA**.
3. Hitung checksum untuk verifikasi peserta:
   ```powershell
   certutil -hashfile blueforge-2026.04.ova SHA256
   ```
4. Unggah OVA + checksum ke **GitHub Releases** atau Google Drive → bagikan link.
   (Lihat `image/README.md`.)

---

**Ada kendala di langkah tertentu?** Buka [issue](../../issues) baru dan sertakan
nomor langkah + pesan error yang muncul.
