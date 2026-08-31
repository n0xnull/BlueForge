#!/usr/bin/env bash
# =====================================================================
# BlueForge — Provision canonical "dirty state" (v0.3 / 15 celah)
#
# Dua fase, SELALU dijalankan berurutan tiap kali skrip ini dipanggil:
#   FASE 1 (RESET)  — kembalikan VM ke kondisi bersih/deterministik, buang
#                     sisa state dari provisioning/percobaan sebelumnya
#                     (user rogue lama, unit systemd, rule ufw kustom, dst).
#   FASE 2 (PLANT)  — tanam ulang SEMUA 15 celah dari kondisi bersih itu.
#
# Kenapa ada FASE 1: skrip ini sering dijalankan berkali-kali di VM yang
# sama saat testing (bukan cuma sekali sebelum lomba) — kalau langsung
# "plant" tanpa reset dulu, celah bisa tertimpa state sisa run/fix
# sebelumnya (mis. unit systemd ter-mask, rule ufw custom, ip_forward
# ter-persist di sysctl.conf) sehingga hasilnya tidak deterministik.
# Tingkat kesulitan (dipilih di web) menentukan SUBSET mana yang dinilai —
# jadi di sini kita tetap menanam semuanya.
#
# Jalankan di VM base sbg root.  PERINGATAN: hanya untuk VM lomba terisolasi.
# =====================================================================
set -uo pipefail
if [[ $EUID -ne 0 ]]; then echo "Jalankan sebagai root (sudo)."; exit 1; fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== FASE 1/2 — RESET: membersihkan sisa provisioning sebelumnya =="

# Rogue users: hapus dulu (kalau ada) supaya recreate di FASE 2 benar-benar
# fresh (home dir, password, keanggotaan grup tidak membawa sisa state lama).
for u in hacker guest2 backdoor; do
  deluser --remove-home "$u" >/dev/null 2>&1 || true
done
userdel -f rootkit >/dev/null 2>&1 || true

# UFW: buang rule kustom (bukan cuma disable) supaya rule bersih sebelum
# dipakai lagi di lomba berikutnya.
ufw --force reset >/dev/null 2>&1 || true

# dhc-telnetd: lepas mask/disable dari percobaan fix sebelumnya, biar
# FASE 2 bisa enable--now dengan bersih (systemctl enable gagal diam-diam
# kalau unit sedang di-mask).
systemctl unmask dhc-telnetd >/dev/null 2>&1 || true
systemctl disable --now dhc-telnetd >/dev/null 2>&1 || true
# sisa-sisa upaya lama pakai telnetd/inetd asli (kalau pernah dipasang manual)
systemctl disable --now inetd >/dev/null 2>&1 || true
systemctl disable --now telnetd >/dev/null 2>&1 || true

# ip_forward: hapus override persisten yang mungkin ditambahkan peserta saat
# fix (mis. "echo net.ipv4.ip_forward=0 >> /etc/sysctl.conf") — kalau
# dibiarkan, nilai ini akan menang lagi setiap kali VM reboot walau FASE 2
# sudah men-set ulang runtime value-nya.
sed -i '/^net\.ipv4\.ip_forward/d' /etc/sysctl.conf 2>/dev/null || true
grep -rl '^net\.ipv4\.ip_forward' /etc/sysctl.d/ 2>/dev/null | xargs -r sed -i '/^net\.ipv4\.ip_forward/d' || true
rm -f /etc/sysctl.d/99-blueforge-ipforward.conf

echo "== FASE 2/2 — PLANT: menanam 15 celah dari kondisi bersih =="

# 1 ssh_root_disabled -> PermitRootLogin yes
if [[ -f /etc/ssh/sshd_config ]]; then
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  grep -q '^PermitRootLogin' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
fi

# 11 ssh_permitempty_disabled -> PermitEmptyPasswords yes
if [[ -f /etc/ssh/sshd_config ]]; then
  sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords yes/' /etc/ssh/sshd_config
  grep -q '^PermitEmptyPasswords' /etc/ssh/sshd_config || echo 'PermitEmptyPasswords yes' >> /etc/ssh/sshd_config
  systemctl restart ssh 2>/dev/null || true
fi

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

# 9 ip_forward_disabled -> nyalakan (PERSISTEN via drop-in, bukan cuma
# "sysctl -w" runtime). "sysctl -w" hanya mengubah nilai LIVE di kernel
# saat script ini dijalankan panitia -- tidak ditulis ke disk. Begitu VM
# ini di-export ke OVA lalu di-import & di-boot ulang oleh peserta
# ("start BlueForge"), kernel boot dengan nilai default (0), sehingga
# poin "Nonaktifkan IP Forwarding" langsung PASS/tercentang sendiri tanpa
# peserta berbuat apa-apa. Drop-in ini membuat nilai 1 bertahan lintas
# reboot, sama seperti celah-celah lain yang memang disk-backed.
cat > /etc/sysctl.d/99-blueforge-ipforward.conf <<'EOF'
net.ipv4.ip_forward=1
EOF
sysctl --system >/dev/null 2>&1 || sysctl -p /etc/sysctl.d/99-blueforge-ipforward.conf >/dev/null 2>&1 || true

# 10 password_max_days -> set 99999
if grep -q '^PASS_MAX_DAYS' /etc/login.defs; then
  sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t99999/' /etc/login.defs
else
  echo 'PASS_MAX_DAYS	99999' >> /etc/login.defs
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

echo "== Selesai. 15 celah tertanam dari kondisi bersih. =="
echo "   Verifikasi cepat listener telnet: ss -ltnp | grep ':23 '"
echo "   Catat image_version & hitung baseline hash sebelum export OVA."
