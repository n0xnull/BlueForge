#!/usr/bin/env bash
# =====================================================================
# BlueForge — Provision canonical "dirty state" (v0.4 / 30 celah)
#
# Dua fase, SELALU dijalankan berurutan tiap kali skrip ini dipanggil:
#   FASE 1 (RESET)  — kembalikan VM ke kondisi bersih/deterministik, buang
#                     sisa state dari provisioning/percobaan sebelumnya
#                     (user rogue lama, unit systemd, rule ufw kustom, dst).
#   FASE 2 (PLANT)  — tanam ulang SEMUA 30 celah dari kondisi bersih itu.
#
# Kenapa ada FASE 1: skrip ini sering dijalankan berkali-kali di VM yang
# sama saat testing (bukan cuma sekali sebelum lomba) — kalau langsung
# "plant" tanpa reset dulu, celah bisa tertimpa state sisa run/fix
# sebelumnya (mis. unit systemd ter-mask, rule ufw custom, ip_forward
# ter-persist di sysctl.conf) sehingga hasilnya tidak deterministik.
# Tingkat kesulitan (dipilih di web) menentukan SUBSET mana yang dinilai —
# jadi di sini kita tetap menanam semuanya. Preset "fitcom" (v0.4) memakai
# seluruh 30 celah untuk lomba FITCOM (durasi ~2 jam 30 menit).
#
# v0.4: +15 celah baru (#16-#30) dibanding v0.3 (15 celah). Lihat
# db/seed/difficulties.sql & docs/kunci jawaban di Guide_How_to_Run.txt
# untuk daftar & command perbaikan lengkap.
#
# Jalankan di VM base sbg root.  PERINGATAN: hanya untuk VM lomba terisolasi.
# =====================================================================
set -uo pipefail
if [[ $EUID -ne 0 ]]; then echo "Jalankan sebagai root (sudo)."; exit 1; fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== FASE 1/2 — RESET: membersihkan sisa provisioning sebelumnya =="

# blueforge-agent: hapus sesi lokal (session_state.json) kalau ada -- file
# ini dibuat OTOMATIS oleh agen begitu ada yang berhasil registrasi lewat
# kiosk (lihat agent/main.py). Kalau tertinggal di VM MASTER saat sedang
# uji-coba/smoke-test agen, lalu VM ini di-export & di-clone ke SEMUA
# komputer peserta, maka SETIAP klon akan boot dengan sesi peserta test itu
# ter-restore otomatis -- semua peserta akan tampak sebagai satu identitas
# yang sama. WAJIB bersih sebelum export; provision.sh SELALU dijalankan
# ulang tepat sebelum export (lihat checklist pra-lomba), jadi baris ini
# jadi jaring pengaman otomatis.
rm -f /opt/blueforge-agent/session_state.json /opt/blueforge-agent/session_state.json.tmp 2>/dev/null || true

# Rogue users: hapus dulu (kalau ada) supaya recreate di FASE 2 benar-benar
# fresh (home dir, password, keanggotaan grup tidak membawa sisa state lama).
for u in hacker guest2 backdoor svc-backup dhcspy1 dhcspy2; do
  deluser --remove-home "$u" >/dev/null 2>&1 || true
done
userdel -f rootkit >/dev/null 2>&1 || true

# UFW: buang rule kustom (bukan cuma disable) supaya rule bersih sebelum
# dipakai lagi di lomba berikutnya.
ufw --force reset >/dev/null 2>&1 || true

# dhc-telnetd / dhc-ftpd / dhc-listener: lepas mask/disable dari percobaan
# fix sebelumnya, biar FASE 2 bisa enable--now dengan bersih (systemctl
# enable gagal diam-diam kalau unit sedang di-mask).
for svc in dhc-telnetd dhc-ftpd dhc-listener; do
  systemctl unmask "$svc" >/dev/null 2>&1 || true
  systemctl disable --now "$svc" >/dev/null 2>&1 || true
done
# sisa-sisa upaya lama pakai telnetd/inetd/vsftpd asli (kalau pernah dipasang manual)
systemctl disable --now inetd >/dev/null 2>&1 || true
systemctl disable --now telnetd >/dev/null 2>&1 || true
systemctl disable --now vsftpd >/dev/null 2>&1 || true

# ip_forward: hapus override persisten yang mungkin ditambahkan peserta saat
# fix (mis. "echo net.ipv4.ip_forward=0 >> /etc/sysctl.conf") — kalau
# dibiarkan, nilai ini akan menang lagi setiap kali VM reboot walau FASE 2
# sudah men-set ulang runtime value-nya.
sed -i '/^net\.ipv4\.ip_forward/d' /etc/sysctl.conf 2>/dev/null || true
grep -rl '^net\.ipv4\.ip_forward' /etc/sysctl.d/ 2>/dev/null | xargs -r sed -i '/^net\.ipv4\.ip_forward/d' || true
rm -f /etc/sysctl.d/99-blueforge-ipforward.conf

# v0.4 — 5 parameter sysctl baru (soal #21-#25): sama alasannya dengan
# ip_forward di atas — buang override persisten sisa fix peserta sebelum
# ditanam ulang lewat drop-in kita sendiri di FASE 2.
for key in net.ipv4.tcp_syncookies kernel.randomize_va_space \
           net.ipv4.conf.all.accept_redirects net.ipv4.conf.all.accept_source_route \
           fs.suid_dumpable; do
  esc="$(printf '%s' "$key" | sed 's/\./\\./g')"
  sed -i "/^${esc}/d" /etc/sysctl.conf 2>/dev/null || true
  grep -rl "^${esc}" /etc/sysctl.d/ 2>/dev/null | xargs -r sed -i "/^${esc}/d" || true
done
rm -f /etc/sysctl.d/99-blueforge-hardening.conf

# v0.4 — berkas/mekanisme celah baru lain: hapus dulu, FASE 2 menanam ulang
# dari kondisi bersih (deterministik, tidak peduli sisa fix peserta).
rm -f /etc/profile.d/99-dhc-path.sh
rm -f /opt/dhc/backup.sh /etc/cron.d/dhc-backup
rm -f /var/spool/cron/crontabs/svc-backup

echo "== FASE 2/2 — PLANT: menanam 30 celah dari kondisi bersih =="

# 1 ssh_root_disabled -> PermitRootLogin yes
if [[ -f /etc/ssh/sshd_config ]]; then
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  grep -q '^PermitRootLogin' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
fi

# 11 ssh_permitempty_disabled -> PermitEmptyPasswords yes
if [[ -f /etc/ssh/sshd_config ]]; then
  sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords yes/' /etc/ssh/sshd_config
  grep -q '^PermitEmptyPasswords' /etc/ssh/sshd_config || echo 'PermitEmptyPasswords yes' >> /etc/ssh/sshd_config
fi

# 17 ssh_x11_forwarding_disabled -> X11Forwarding yes
if [[ -f /etc/ssh/sshd_config ]]; then
  sed -i 's/^#\?X11Forwarding.*/X11Forwarding yes/' /etc/ssh/sshd_config
  grep -q '^X11Forwarding' /etc/ssh/sshd_config || echo 'X11Forwarding yes' >> /etc/ssh/sshd_config
fi

# 18 ssh_max_auth_tries_limited -> MaxAuthTries 10 (default OpenSSH = 6, kita
# naikkan eksplisit supaya soal ini deterministik gagal di semua image)
if [[ -f /etc/ssh/sshd_config ]]; then
  sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 10/' /etc/ssh/sshd_config
  grep -q '^MaxAuthTries' /etc/ssh/sshd_config || echo 'MaxAuthTries 10' >> /etc/ssh/sshd_config
fi

systemctl restart ssh 2>/dev/null || true

# 2 ufw_enabled -> matikan firewall
apt-get install -y ufw >/dev/null 2>&1 || true
ufw --force disable >/dev/null 2>&1 || true

# 3 telnet_disabled -> listener port 23 SENDIRI (bukan paket telnetd, lihat
# dhc-telnetd.py — paket telnetd/inetd asli sudah tidak dapat diandalkan di
# rilis Ubuntu modern, sehingga soal ini dulu bisa "PASS sendiri" tanpa
# peserta berbuat apa-apa).
install -m 755 "$SCRIPT_DIR/dhc-telnetd.py" /usr/local/sbin/dhc-telnetd.py
install -m 644 "$SCRIPT_DIR/dhc-telnetd.service" /etc/systemd/system/dhc-telnetd.service
systemctl daemon-reload
systemctl enable --now dhc-telnetd

# 16 ftp_disabled -> listener port 21 SENDIRI, pola identik dengan dhc-telnetd
install -m 755 "$SCRIPT_DIR/dhc-ftpd.py" /usr/local/sbin/dhc-ftpd.py
install -m 644 "$SCRIPT_DIR/dhc-ftpd.service" /etc/systemd/system/dhc-ftpd.service
systemctl daemon-reload
systemctl enable --now dhc-ftpd

# 30 backdoor_listener_removed -> listener backdoor/reverse-shell palsu port 4444
install -m 755 "$SCRIPT_DIR/dhc-listener.py" /usr/local/sbin/dhc-listener.py
install -m 644 "$SCRIPT_DIR/dhc-listener.service" /etc/systemd/system/dhc-listener.service
systemctl daemon-reload
systemctl enable --now dhc-listener

# 4 rogue_user_removed -> user 'hacker'
id hacker >/dev/null 2>&1 || { useradd -m -s /bin/bash hacker 2>/dev/null || true; echo 'hacker:password123' | chpasswd 2>/dev/null || true; }

# 5 shadow_perm -> longgarkan
chmod 644 /etc/shadow 2>/dev/null || true

# 6 passwd_perm -> world-writable
chmod 666 /etc/passwd 2>/dev/null || true

# 7 empty_password_removed -> akun password kosong
id guest2 >/dev/null 2>&1 || useradd -m -s /bin/bash guest2 2>/dev/null || true
passwd -d guest2 >/dev/null 2>&1 || true

# 8 uid0_unique -> akun UID 0 palsu
id rootkit >/dev/null 2>&1 || useradd -o -u 0 -M -s /bin/bash rootkit 2>/dev/null || true

# 29 duplicate_uid_removed -> dua akun berbeda berbagi UID 1500 (bukan UID 0,
# supaya beda konsep dengan soal #8 di atas — sengaja pakai user baru, BUKAN
# akun default peserta manapun, supaya tidak tergantung nama user image).
id dhcspy1 >/dev/null 2>&1 || useradd -o -u 1500 -M -s /usr/sbin/nologin dhcspy1 2>/dev/null || true
id dhcspy2 >/dev/null 2>&1 || useradd -o -u 1500 -M -s /usr/sbin/nologin dhcspy2 2>/dev/null || true

# 9 root_home_perm -> buat direktori /root world-readable & world-executable (777)
# agar peserta harus memperbaiki izin akses /root menjadi mode 700 atau 750.
chmod 777 /root
rm -f /etc/sysctl.d/99-blueforge-ipforward.conf 2>/dev/null || true

# 21-25 (v0.4) — 5 parameter sysctl tambahan, drop-in terpisah
# PERSISTEN lintas reboot.
cat > /etc/sysctl.d/99-blueforge-hardening.conf <<'EOF'
net.ipv4.tcp_syncookies=0
kernel.randomize_va_space=0
net.ipv4.conf.all.accept_redirects=1
net.ipv4.conf.all.accept_source_route=1
fs.suid_dumpable=2
EOF
sysctl --system >/dev/null 2>&1 || sysctl -p /etc/sysctl.d/99-blueforge-hardening.conf >/dev/null 2>&1 || true

# 10 password_max_days -> set 99999
if grep -q '^PASS_MAX_DAYS' /etc/login.defs; then
  sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t99999/' /etc/login.defs
else
  echo 'PASS_MAX_DAYS	99999' >> /etc/login.defs
fi

# 20 password_min_days_set -> set 0
if grep -q '^PASS_MIN_DAYS' /etc/login.defs; then
  sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS\t0/' /etc/login.defs
else
  echo 'PASS_MIN_DAYS	0' >> /etc/login.defs
fi

# 12 world_writable_removed -> file sentinel 777
mkdir -p /opt/dhc; echo "rahasia" > /opt/dhc/secret.txt; chmod 777 /opt/dhc/secret.txt

# 13 suid_bash_removed -> backdoor SUID
cp /bin/bash /usr/local/bin/rootbash 2>/dev/null && chmod 4755 /usr/local/bin/rootbash 2>/dev/null || true

# 14 rogue_sudo_removed -> user 'backdoor' di grup sudo
id backdoor >/dev/null 2>&1 || useradd -m -s /bin/bash backdoor 2>/dev/null || true
usermod -aG sudo backdoor 2>/dev/null || true

# 15 cron_backdoor_removed -> cron mencurigakan
cat > /etc/cron.d/dhc-backdoor <<'EOF'
* * * * * root /bin/true
EOF

# 8 default_umask_set -> set UMASK ke 000 di /etc/login.defs
if grep -q '^UMASK' /etc/login.defs; then
  sed -i 's/^UMASK.*/UMASK\t000/' /etc/login.defs
else
  echo 'UMASK	000' >> /etc/login.defs
fi

# 26 unsafe_path_removed -> sisipkan '.' (current dir) ke PATH global lewat
# drop-in profile.d milik kita sendiri (BUKAN mengedit /etc/profile langsung,
# supaya gampang & aman dibersihkan/diverifikasi terpisah).
cat > /etc/profile.d/99-dhc-path.sh <<'EOF'
# abilithic DHC -- SENGAJA rentan: menambahkan direktori kerja saat ini (.)
# ke PATH global, membuka celah PATH hijacking (soal unsafe_path_removed).
export PATH=".:$PATH"
EOF
chmod 644 /etc/profile.d/99-dhc-path.sh

# 27 rogue_crontab_removed -> crontab pribadi mencurigakan milik akun layanan
id svc-backup >/dev/null 2>&1 || useradd -r -M -s /usr/sbin/nologin svc-backup 2>/dev/null || true
mkdir -p /var/spool/cron/crontabs
cat > /var/spool/cron/crontabs/svc-backup <<'EOF'
# DO NOT EDIT THIS FILE - edit the master and reinstall.
# (abilithic DHC -- SENGAJA rentan, soal rogue_crontab_removed)
* * * * * curl -s http://169.254.169.254/latest/meta-data/ >> /tmp/.cache 2>/dev/null
EOF
chown svc-backup:crontab /var/spool/cron/crontabs/svc-backup 2>/dev/null || chown svc-backup /var/spool/cron/crontabs/svc-backup 2>/dev/null || true
chmod 600 /var/spool/cron/crontabs/svc-backup

# 28 cron_writable_script_removed -> cron root menjalankan script world-writable
mkdir -p /opt/dhc
cat > /opt/dhc/backup.sh <<'EOF'
#!/bin/bash
# abilithic DHC -- placeholder, dijalankan cron sbg root tiap menit
# (soal cron_writable_script_removed -- masalahnya ada di izin akses file ini)
/bin/true
EOF
chmod 777 /opt/dhc/backup.sh
cat > /etc/cron.d/dhc-backup <<'EOF'
* * * * * root /opt/dhc/backup.sh
EOF

# ---------------------------------------------------------------------
# Bersihkan command history -- WAJIB sebelum export OVA. VM ini dipakai
# berkali-kali buat uji coba (jalankan provision.sh, cek soal, dst) dan
# semua command itu numpuk di riwayat shell user login (`cyber`) maupun
# root. Kalau kebawa ke image final, peserta tinggal ketik `history` di
# terminal mereka utk lihat persis command apa saja yang panitia jalankan
# -- bisa membocorkan cara vulnerability ditanam / jalan pintas jawaban.
# Sengaja jadi LANGKAH TERAKHIR provision.sh (bukan di FASE 1/RESET di
# awal), supaya turut membersihkan command dari eksekusi provision.sh
# ITU SENDIRI barusan.
echo "== Membersihkan command history (root & user login) =="
for hist_home in /root "/home/cyber" "$( [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]] && getent passwd "$SUDO_USER" | cut -d: -f6 )"; do
  [[ -n "$hist_home" && -d "$hist_home" ]] || continue
  for f in "$hist_home/.bash_history" "$hist_home/.zsh_history"; do
    [[ -f "$f" ]] && : > "$f"
  done
done
history -c 2>/dev/null || true
echo "   File riwayat (~/.bash_history) sudah dikosongkan utk root & cyber."
echo "   PENTING: ini cuma membersihkan FILE-nya. Kalau kamu masih mengetik"
echo "   command LAIN di terminal ini setelah baris ini (mis. cek manual,"
echo "   verifikasi tambahan), jalankan 'history -c' sekali lagi di shell"
echo "   kamu SEBELUM export OVA -- bash biasanya menulis ulang riwayat sesi"
echo "   yang sedang berjalan ke file itu saat shell ditutup/exit normal."

echo "== Selesai. 30 celah tertanam dari kondisi bersih. =="
echo "   Verifikasi cepat listener telnet/ftp/backdoor:"
echo "     ss -ltnp | grep -E ':23 |:21 |:4444 '"
echo "   Catat image_version & hitung baseline hash sebelum export OVA."
