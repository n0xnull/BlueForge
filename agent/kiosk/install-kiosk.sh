#!/usr/bin/env bash
# =====================================================================
# BlueForge — Pasang mode KIOSK di VM peserta.
# Setelah ini: VM boot -> aplikasi BlueForge muncul otomatis.
# Jalankan dari folder repo:  sudo bash agent/kiosk/install-kiosk.sh
# =====================================================================
set -euo pipefail
if [[ $EUID -ne 0 ]]; then echo "Jalankan dengan sudo."; exit 1; fi

# user desktop yang sebenarnya (bukan root)
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
if [[ -z "$TARGET_USER" ]]; then echo "Tidak bisa deteksi user desktop. Set TARGET_USER manual."; exit 1; fi
USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[1/6] Install dependency Python..."
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y python3-flask python3-requests python3-yaml >/dev/null 2>&1 || \
  pip3 install -r "$REPO_DIR/agent/requirements.txt" --break-system-packages || true

echo "[2/6] (opsional) Coba pasang pywebview untuk jendela native..."
# Tidak wajib — kalau gagal, kiosk pakai browser mode. Jangan hentikan skrip.
apt-get install -y python3-gi gir1.2-webkit2-4.1 >/dev/null 2>&1 || true
pip3 install pywebview --break-system-packages >/dev/null 2>&1 || true

echo "[3/6] Salin agent ke /opt/blueforge-agent..."
mkdir -p /opt/blueforge-agent
cp -r "$REPO_DIR/agent/." /opt/blueforge-agent/
# pastikan ada config.yaml (kalau belum, dari contoh — INGAT set portal_url!)
if [[ ! -f /opt/blueforge-agent/config.yaml ]]; then
  cp /opt/blueforge-agent/config.example.yaml /opt/blueforge-agent/config.yaml
  echo "    !! Belum ada config.yaml -> dibuat dari contoh. EDIT portal_url:"
  echo "       sudo nano /opt/blueforge-agent/config.yaml"
fi
chmod +x /opt/blueforge-agent/kiosk.py /opt/blueforge-agent/main.py 2>/dev/null || true
chmod +x /opt/blueforge-agent/kiosk/restart-kiosk.sh 2>/dev/null || true

echo "[4/6] Pasang autostart untuk user $TARGET_USER..."
install -d -o "$TARGET_USER" -g "$TARGET_USER" "$USER_HOME/.config/autostart"
cp "$REPO_DIR/agent/kiosk/blueforge.desktop" "$USER_HOME/.config/autostart/"
chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/.config/autostart/blueforge.desktop"

echo "[5/6] Pasang shortcut restart manual di Desktop (fallback kalau window macet)..."
install -d -o "$TARGET_USER" -g "$TARGET_USER" "$USER_HOME/Desktop"
cp "$REPO_DIR/agent/kiosk/restart-kiosk.desktop" "$USER_HOME/Desktop/"
chmod +x "$USER_HOME/Desktop/restart-kiosk.desktop"
chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/Desktop/restart-kiosk.desktop"
# GNOME/Nautilus menandai .desktop di Desktop sebagai "untrusted" sampai
# ditandai manual -- coba tandai otomatis lewat gio (kalau gagal, peserta/
# panitia cukup klik kanan -> "Allow Launching" sekali saja).
sudo -u "$TARGET_USER" gio set "$USER_HOME/Desktop/restart-kiosk.desktop" "metadata::trusted" "true" 2>/dev/null || true

echo "[6/6] Selesai."
cat <<EOF

============================================================
 KIOSK TERPASANG.
 - Aplikasi BlueForge akan muncul otomatis saat login desktop, dan otomatis
   membuka lagi sendiri kalau jendela tidak sengaja tertutup peserta.
 - Kalau suatu saat window benar-benar macet/hilang, ada shortcut
   "Restart BlueForge" di Desktop -- tinggal double-click, tidak
   perlu buka terminal.
 - Uji sekarang tanpa reboot:
     python3 /opt/blueforge-agent/kiosk.py
 - Pastikan config sudah benar (portal_url ke URL Vercel):
     sudo nano /opt/blueforge-agent/config.yaml
 - Jangan lupa tanam celah sebelum lomba:
     sudo bash "$REPO_DIR/image/build/provision.sh"

 (Opsional) Auto-login desktop tanpa ketik password:
   sudo nano /etc/gdm3/custom.conf   -> pada [daemon] tambahkan:
     AutomaticLoginEnable=true
     AutomaticLogin=$TARGET_USER
============================================================
EOF
