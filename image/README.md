# Image VM — BlueForge

> **OVA tidak disimpan di repo** (terlalu besar). Repo hanya menyimpan **script pembangun**.

## ⬇️ Download

| File | Link |
|---|---|
| **BlueForge VM (.ova)** | [Google Drive — tinyurl.com/BlueForge-VMWare](https://tinyurl.com/BlueForge-VMWare) |
| **VMware Workstation Player** | [vmware.com/products/workstation-player](https://www.vmware.com/products/workstation-player.html) |

**Cara import:**
1. Buka VMware → **File → Open** → pilih file `.ova`.
2. Import → jalankan VM.
3. Boot → kiosk BlueForge muncul otomatis.

> Setelah import (khusus panitia): jalankan `sudo bash ~/BlueForge/image/build/provision.sh`
> sekali untuk menanam celah sebelum VM didistribusikan ke peserta.

## Cara membangun base image (ringkas)

1. Install **Ubuntu Server 24.04 LTS** di VMware (lihat TDD). Update penuh:
   ```bash
   sudo apt update && sudo apt -y upgrade
   ```
2. **Snapshot "clean baseline"** di VMware (titik balik aman).
3. Pasang agen:
   ```bash
   sudo mkdir -p /opt/blueforge-agent
   sudo cp -r agent/* /opt/blueforge-agent/
   cd /opt/blueforge-agent && sudo cp config.example.yaml config.yaml
   # edit config.yaml -> portal_url ke URL produksi
   sudo apt -y install python3-pip && sudo pip3 install -r requirements.txt
   sudo cp systemd/blueforge-agent.service /etc/systemd/system/
   sudo systemctl daemon-reload && sudo systemctl enable --now blueforge-agent
   ```
4. **Tanam celah (canonical dirty state)** menggunakan `image/build/provision.sh`
   sesuai daftar 5 check v0.1.
5. Catat `image_version` & hitung `canonical_baseline_hash`.
6. **Export OVA**: `File → Export to OVF/OVA`. Hitung checksum:
   ```bash
   sha256sum blueforge-2024.04.ova
   ```
7. Unggah OVA + checksum ke Releases. Bagikan link ke peserta.

## Daftar celah (15 check, v0.3)

`image/build/provision.sh` sekarang dua fase: **RESET** (bersihkan sisa
provisioning/percobaan sebelumnya — user rogue lama, unit systemd, rule ufw
kustom, override `ip_forward` yang ter-persist) lalu **PLANT** (tanam ulang
semua 15 celah dari kondisi bersih itu). Aman dijalankan berkali-kali di VM
yang sama saat testing — hasilnya selalu deterministik.

| code | Kondisi rentan (yang ditanam) |
|---|---|
| ssh_root_disabled | `PermitRootLogin yes` di sshd_config |
| ufw_enabled | UFW inactive |
| telnet_disabled | listener `dhc-telnetd.service` di port 23 (lihat catatan di bawah) |
| rogue_user_removed | user `hacker` ditambahkan |
| shadow_perm | `/etc/shadow` di-chmod 644 |
| passwd_perm | `/etc/passwd` di-chmod 666 |
| empty_password_removed | user `guest2` tanpa password |
| uid0_unique | user `rootkit` ber-UID 0 |
| ip_forward_disabled | `net.ipv4.ip_forward=1` |
| password_max_days | `PASS_MAX_DAYS 99999` di login.defs |
| ssh_permitempty_disabled | `PermitEmptyPasswords yes` di sshd_config |
| world_writable_removed | `/opt/dhc/secret.txt` di-chmod 777 |
| suid_bash_removed | `/usr/local/bin/rootbash` (copy bash ber-bit SUID) |
| rogue_sudo_removed | user `backdoor` ditambahkan ke grup sudo |
| cron_backdoor_removed | `/etc/cron.d/dhc-backdoor` |

> **Kenapa `telnet_disabled` tidak lagi pakai paket `telnetd`**: paket itu
> sudah tak bisa diandalkan (kadang tak tersedia/tak bisa jalan lewat
> systemd) di rilis Ubuntu modern, sehingga soal ini bisa "PASS sendiri"
> tanpa peserta berbuat apa-apa. Diganti listener TCP minimal sendiri
> (`dhc-telnetd.py` + `dhc-telnetd.service`) yang selalu bisa jalan di
> versi Ubuntu berapa pun — lihat komentar di `dhc-telnetd.py`.

Lihat `image/build/provision.sh`.
