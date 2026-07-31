# Mode Kiosk — Agent jadi "Aplikasi" (v0.2)

Tujuan: peserta **tidak** perlu buka browser/localhost manual. VM dinyalakan →
**aplikasi BlueForge muncul otomatis sebagai jendela panel** → isi Nama + Kode Sesi →
setelah START jadi **live dashboard** (skor, timer, checklist, hint).

> **PENTING (companion window, bukan kunci layar):** aplikasi muncul sebagai
> **jendela panel ramping**, BUKAN fullscreen yang mengunci. Peserta tetap bisa
> membuka **Terminal** dan bekerja (hardening) sambil melihat skornya naik di panel.
> Ini disengaja — lomba hardening butuh akses terminal & editor.

## Cara peserta mengerjakan
1. Boot VM → panel **BlueForge** muncul → isi Nama + Kode Sesi → **Daftar**.
2. Tunggu panitia **START**. Panel berubah jadi dashboard (skor, timer, checklist).
3. Buka **Terminal** (Activities → ketik "Terminal") **di samping** panel.
4. Perbaiki tiap tugas di checklist lewat terminal/editor. Skor naik otomatis di panel
   dalam beberapa detik. Hint tampil untuk tugas yang belum selesai.
5. Saat waktu habis, skor dibekukan.

## Cara kerja
`kiosk.py` menjalankan agent di latar, menunggu UI lokal siap, lalu menampilkannya
sebagai aplikasi fullscreen:
1. **pywebview** (jendela native, tanpa browser chrome) — jika terpasang.
2. Fallback andal: **browser mode kiosk** (Firefox `--kiosk` / Chromium `--app --kiosk`).

Logika agent & scoring **tidak berubah** — kiosk hanya pembungkus tampilan (TDD §27).

## Pasang di VM (sekali saja)

Dari dalam VM, di folder repo:
```bash
cd ~/BlueForge
git pull                                   # ambil update v0.2
sudo bash agent/kiosk/install-kiosk.sh
```
Skrip ini:
- pasang dependency Python (+ coba pywebview, opsional),
- salin agent ke `/opt/blueforge-agent`,
- pasang **autostart** agar app muncul saat login desktop.

Lalu set URL portal (kalau belum):
```bash
sudo nano /opt/blueforge-agent/config.yaml   # portal_url = URL Vercel kamu
```

## Uji tanpa reboot
```bash
python3 /opt/blueforge-agent/kiosk.py
```
Aplikasi fullscreen harus muncul. Tekan **Alt+F4** (atau `pkill firefox`/`pkill -f kiosk.py`
dari TTY lain) untuk menutup saat menguji.

## (Opsional) Auto-login desktop
Agar peserta tak perlu ketik password Ubuntu:
```bash
sudo nano /etc/gdm3/custom.conf
```
Pada bagian `[daemon]` tambahkan:
```
AutomaticLoginEnable=true
AutomaticLogin=NAMA_USER_KAMU
```
Reboot → VM langsung masuk desktop → aplikasi BlueForge muncul otomatis. Pengalaman
"appliance" yang profesional. ✅

## Sebelum lomba: tanam celah
```bash
sudo bash ~/BlueForge/image/build/provision.sh
```

## Untuk distribusi (nanti)
Setelah semua beres di satu VM: matikan VM → **File → Export to OVA** → bagikan ke
peserta. Mereka cukup import & nyalakan → app langsung jalan. (Lihat `image/README.md`.)

## Troubleshooting
| Masalah | Solusi |
|---|---|
| App tak muncul saat boot | Uji manual `python3 /opt/blueforge-agent/kiosk.py`; cek autostart ada di `~/.config/autostart/` |
| Layar putih / "tidak bisa hubungi agent" | `portal_url` salah, atau agent belum siap — tunggu beberapa detik |
| pywebview error | Abaikan — otomatis fallback ke browser kiosk (Firefox/Chromium) |
| Mau keluar dari kiosk | Alt+F4, atau dari TTY lain: `pkill -f kiosk.py` |
