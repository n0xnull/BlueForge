# Changelog

Semua perubahan penting dicatat di sini. Format: [Keep a Changelog](https://keepachangelog.com),
versi mengikuti [SemVer](https://semver.org) (TDD §24).

## [Unreleased]
### Added — v0.4 (persiapan lomba FITCOM, Universitas Dinamika)
- **+15 soal baru (total 30, dari 15)**: `ftp_disabled`, `ssh_x11_forwarding_disabled`,
  `ssh_max_auth_tries_limited`, `tmp_sticky_bit_set`, `password_min_days_set`,
  `syn_cookies_enabled`, `aslr_enabled`, `icmp_redirects_disabled`,
  `source_routing_disabled`, `core_dump_restricted`, `unsafe_path_removed`,
  `rogue_crontab_removed`, `cron_writable_script_removed`,
  `duplicate_uid_removed`, `backdoor_listener_removed`. Masing-masing
  punya celah tertanam sendiri di `image/build/provision.sh` (2 layanan
  palsu baru: `dhc-ftpd` port 21, `dhc-listener` port 4444 — pola identik
  `dhc-telnetd`) supaya soal tidak pernah "PASS sendiri" tanpa peserta
  berbuat apa-apa. Diverifikasi lewat `tests/test_new_checks_sandbox.py`
  (fixture sintetis kondisi rentan vs sudah-diperbaiki utk tiap check).
- **Preset baru `fitcom`** (`db/seed/difficulties.sql`,
  `db/migrations/0002_fitcom_preset.sql`): 30 soal (superset penuh), durasi
  default 2 jam 30 menit, dipakai khusus lomba FITCOM. Preset Easy/Medium/
  Hard lama TIDAK berubah (tetap 6/11/15 soal, masih dipakai utk latihan).
  **Urutan No.1-30 (revisi)**: draf awal cuma menaruh 15 soal baru di
  belakang 15 soal lama (bukan urut kesulitan sungguhan). Diperbaiki jadi
  3 pita nyata -- No.1-11 setara Easy (edit satu baris config/hapus akun),
  No.12-21 setara Medium (kombinasi file/sysctl kernel), No.22-30 setara
  Hard (perlu investigasi/penemuan) -- dan urutan array `active_check_codes`
  ini SEKARANG benar-benar dipakai sbg urutan tampil (kiosk agent & panel
  admin keduanya diberi nomor "No. X" eksplisit, bukan cuma daftar tanpa
  urutan).
- **Hint dirombak jadi guiding-only**: `agent/runner/check_runner.py` tidak
  lagi pernah mengembalikan `hint_advanced` (command jawaban langsung) —
  hint yang tampil di kiosk peserta SEKARANG SELALU cuma mengarahkan
  (`hint_basic`), dan hanya ~25% soal (8 dari 30) yang punya hint sama
  sekali. Field `hint_advanced` di schema/seed dipertahankan demi
  kompatibilitas tapi selalu di-null-kan & tidak pernah dibaca lagi.
- **Indikator anti-curang di admin "Lihat peserta"**: rincian per-soal kini
  ditampilkan (centang hijau = lulus sah, centang MERAH = `eligible=false`
  alias sudah lulus SEBELUM panitia klik START / pre-fix, badge "⚠ Anomali
  start" di baris peserta yang bersangkutan). Sebelumnya panitia sama
  sekali tidak bisa melihat data anti pre-fix yang sebenarnya sudah
  dihitung server sejak v0.1 (`participant_checks.eligible`) — cuma
  memengaruhi skor diam-diam tanpa indikator visual apa pun.
  (`web/app/api/v1/admin/participants/route.ts`, `web/app/admin/page.tsx`)
- **Export CSV hasil lomba** dari admin (`GET /api/v1/admin/export?comp=`) —
  peringkat/nama/sekolah/status/skor/jumlah soal selesai (sah), utk
  sertifikat & laporan panitia tanpa query manual ke Supabase.
- **Anti-replay nonce diaktifkan**: tabel `nonces` sudah ada sejak v0.1 tapi
  tak pernah benar-benar dicek — `verifyAgentRequest` (`web/lib/hmac.ts`)
  sekarang menegakkannya di 4 endpoint agen (state/score/snapshot/heartbeat),
  fail-open kalau infra DB bermasalah supaya tidak memblokir seluruh lomba.
- **Rate limit percobaan login admin** (`web/app/api/v1/admin/login/route.ts`)
  — dibackend ke `event_logs` (bukan in-memory) supaya efektif di
  lingkungan serverless; 6 percobaan gagal/10 menit per IP lalu diblokir.
- **Agen tahan crash/reboot VM ("worst case" peserta punya sudo penuh)**:
  sebelumnya seluruh status registrasi (`participant_id`, `agent_secret`)
  cuma hidup di memori proses -- proses/VM mati karena apa pun (exception
  tak tertangkap, `sudo reboot`/`sudo pkill python3` tak sengaja, VM hang)
  berarti peserta wajib isi form registrasi lagi, dan itu DITOLAK server
  (unique constraint `competition_id,full_name,school`) karena baris
  lamanya masih ada -- peserta terkunci total sampai panitia turun tangan
  manual. Diperbaiki 2 lapis: (1) `agent/main.py` sekarang menulis sesi ke
  `session_state.json` lokal segera setelah registrasi & memuatnya ulang
  otomatis saat proses start, jadi restart proses/VM biasa PULIH SENDIRI
  tanpa peserta sadar; (2) sebagai jaring pengaman, `POST /api/v1/register`
  sekarang idempoten per identitas -- konflik unique diperlakukan sebagai
  RESUME (kembalikan kredensial peserta yang sama, secret diturunkan ulang
  deterministik) alih-alih ditolak 409, KECUALI peserta itu berstatus
  `disqualified` (supaya "daftar ulang" tidak jadi celah lolos DQ).
  `image/build/provision.sh` juga dibersihkan agar tidak pernah
  mewariskan `session_state.json` sisa uji-coba ke VM peserta lewat
  golden image.
- **Loop utama agen (`agent/main.py`) bisa mati total karena satu
  exception tak terduga**: `sync_once()` tidak dibungkus try/except sama
  sekali di loop utama, dan `get_state()` cuma menangkap error jaringan
  (bukan body 200 yang ternyata bukan JSON valid). systemd `Restart=always`
  jadi jaring pengaman terakhir, tapi tiap crash tetap membuang satu siklus
  poll penuh. Sekarang tiap iterasi loop dibungkus try/except, dan
  `get_state()` menangani body non-JSON dengan aman.

- **`image/build/provision.sh` sekarang otomatis membersihkan command
  history** (`~/.bash_history` root & user login `cyber`) sebagai langkah
  TERAKHIRnya -- sebelumnya ini command manual terpisah yang gampang
  terlewat ("Hapus history terminal" di guide). VM master dipakai
  berulang kali utk uji coba sebelum export, jadi riwayat command bisa
  numpuk & membocorkan cara vulnerability ditanam / jalan pintas jawaban
  kalau sampai kebawa ke image final yang di-clone ke semua peserta.

### Fixed — v0.4
- **Tombol DQ (diskualifikasi) tidak benar-benar bekerja**: akar masalahnya
  `POST /api/v1/heartbeat` SELALU menulis `status:"online"` tanpa syarat
  apa pun — begitu agent peserta yang di-DQ mengirim heartbeat berikutnya
  (~15-20 detik), status di database langsung ketiban balik "online" lagi,
  seolah DQ tak pernah terjadi. `/api/v1/score` juga tidak pernah mengecek
  status PESERTA (hanya status sesi), jadi peserta yang di-DQ tetap bisa
  terus menambah skor. Diperbaiki di 3 lapis: heartbeat tidak lagi menimpa
  status `disqualified`; score menolak submit dari peserta `disqualified`
  (403); `/api/v1/state` sekarang mengirim `participant_status` supaya
  agent (`agent/main.py`) berhenti mengirim skor & kiosk lokal menampilkan
  banner "Kamu telah DIDISKUALIFIKASI panitia". UI admin
  (`partAction` di `web/app/admin/page.tsx`) sebelumnya juga tidak pernah
  mengecek `response.ok` — kegagalan apa pun (mis. sesi admin kedaluwarsa)
  tetap menampilkan toast "berhasil", menutupi kegagalan sungguhan.
- **Toast notifikasi admin (`className="toast"`) tidak punya definisi CSS
  sama sekali** di `globals.css` — tampil sbg teks polos tanpa posisi/gaya,
  gampang tidak kelihatan panitia saat lomba ramai. Ditambahkan style toast
  mengambang yang semestinya.

### Changed
- **Rebrand: abilithic DHC → BlueForge**, part of the NoxNull toolkit
  (studio: [n0xnull](https://github.com/n0xnull)). New electric-blue /
  forged-steel visual identity (anvil + spark icon) — distinct from the
  rest of the toolkit. Renamed `abilithic-agent` service → `blueforge-agent`,
  `/opt/abilithic-agent` → `/opt/blueforge-agent`, kiosk desktop entries,
  and all branding strings across web, agent, and docs.

### Fixed
- **`kiosk.py` menjalankan `main.py` duplikat, rebutan port 9090 dengan
  `blueforge-agent.service` (systemd)**: ditemukan lewat log
  `/tmp/blueforge-kiosk.log` yang menunjukkan "Address already in use"
  setiap kali kiosk (re)start. Karena systemd sudah menjalankan `main.py`
  terus-menerus di instalasi kiosk normal, `kiosk.py` yang IKUT menjalankan
  salinan `main.py` sendiri (`start_agent()`) menyebabkan proses kedua ini
  gagal bind port dan mati, sekaligus berpotensi bikin UI/registrasi
  bertingkah aneh. Fix: `start_agent()` (`agent/kiosk.py`) sekarang cek dulu
  lewat `_agent_already_running()` apakah port 9090 sudah dilayani (mis.
  oleh systemd) sebelum memutuskan menjalankan `main.py` sendiri — aman
  dipakai baik lewat instalasi kiosk (systemd) maupun standalone saat
  development.

### Added
- **Kiosk otomatis membuka lagi kalau jendelanya ditutup**: sebelumnya kalau
  peserta tidak sengaja menutup window (klik close/Alt+F4), `kiosk.py`
  langsung keluar dan peserta kehilangan akses sampai ada yang menjalankan
  ulang manual. Sekarang `main()` (`agent/kiosk.py`) loop selamanya dan
  membuka lagi window otomatis dalam ~2 detik. Sebagai fallback kalau proses
  kiosk-nya sendiri ikut mati, ditambahkan shortcut Desktop **"Restart
  BlueForge"** (`agent/kiosk/restart-kiosk.desktop` +
  `restart-kiosk.sh`) yang tinggal di-double-click tanpa buka terminal.
- **Icon abilithic dipakai konsisten di kiosk**: logo placeholder (`◈`) di
  UI kiosk lokal (`agent/ui/templates/index.html`) diganti gambar asli
  (disajikan lewat route static Flask baru, `agent/ui/static/`), dan ikon
  window/taskbar kiosk (`agent/kiosk/blueforge.desktop`, shortcut
  restart) diarahkan ke ikon yang sama alih-alih ikon generik
  `utilities-terminal`.
- **Panduan troubleshooting VM** ditambahkan di README (ringkas, EN) dan
  `docs/DEPLOYMENT-GUIDE.md` (lengkap, ID): alur run awal, cara update kode
  di VM yang benar (termasuk resync wajib ke `/opt/blueforge-agent/` yang
  sebelumnya sering terlewat), penanganan window kiosk tertutup, dan
  kumpulan command diagnostik umum.
- **Transparansi skor di leaderboard publik**: baris/skor peserta kini bisa
  diklik untuk membuka rincian per-soal (judul + status lulus/belum, plus
  ringkasan "X / Y soal selesai") — sebelumnya leaderboard cuma menampilkan
  nama & angka total. Endpoint baru (publik, read-only, tanpa jawaban/command):
  `GET /api/v1/leaderboard/detail?participant=<id>` (`web/app/api/v1/leaderboard/detail/route.ts`).
  UI: `web/app/page.tsx` (baris expand/collapse), `web/app/globals.css`
  (`.detail-row`, `.detail-grid`, dst.).
- **Hint di kiosk kini klik-untuk-tampil**: sebelumnya hint langsung tampil
  otomatis untuk soal yang belum lulus; sekarang disembunyikan default dan
  baru muncul saat baris soal diklik (klik lagi untuk sembunyikan). Status
  buka/tutup disimpan per soal di sisi klien (`agent/ui/templates/index.html`),
  bertahan walau daftar soal di-render ulang tiap 2 detik.

### Fixed
- **Command perbaikan `empty_password_removed` & `uid0_unique` bisa gagal
  walau sudah "benar" secara logika**, ditemukan setelah dilaporkan pengguna
  mencoba kunci jawaban tapi soal tetap tidak PASS:
  - `uid0_unique`: `sudo userdel rootkit` (tanpa `-f`) ditolak dengan
    `user is currently used by process ...` — false-positive, karena akun
    `rootkit` sengaja berbagi UID 0 dengan `root` (`useradd -o -u 0`), dan
    `userdel` mendeteksi "sedang dipakai" dengan mencocokkan UID, bukan nama
    user; root selalu punya banyak proses berjalan. Fix: **wajib** pakai
    `sudo userdel -f rootkit`.
  - `empty_password_removed`: `sudo passwd -l guest2` bisa tidak konsisten
    mengubah field password di `/etc/shadow` pada akun yang field-nya BENAR-
    BENAR kosong (bukan sekadar terkunci). Diganti rekomendasi utama:
    `sudo usermod -p '!' guest2` — menulis langsung field password ke `!`
    tanpa logika toggle apa pun, hasilnya pasti tidak kosong lagi.
  - Diperbarui di `agent/checks/uid0_unique/manifest.yaml`,
    `agent/checks/empty_password_removed/manifest.yaml`,
    `db/seed/difficulties.sql`, dan kunci jawaban internal panitia.

### Changed
- **Teks 15 soal hardening dibuat lebih profesional**: `title` & `description`
  tiap check (`agent/checks/*/manifest.yaml`, disinkronkan ke
  `db/seed/difficulties.sql`) ditulis ulang jadi kalimat formal lengkap,
  konsisten gaya bahasanya antar-soal (mis. "Nonaktifkan Login Root melalui
  SSH" — sebelumnya "Nonaktifkan SSH root login"). `hint_basic` &
  `hint_advanced` (termasuk command perbaikan) TIDAK dihapus/diubah maknanya
  — beberapa hanya disinkronkan agar identik antara database & agent.

### Fixed
- **Jendela kiosk blank setelah restart VM** (`agent/kiosk.py`), dua penyebab
  sekaligus:
  1. Bug WebKitGTK yang dikenal luas: renderer DMA-BUF-nya sering gagal total
     di GPU virtual (VMware/VirtualBox/QEMU), menghasilkan jendela yang
     terbuka tapi benar-benar blank. Diperbaiki dengan set
     `WEBKIT_DISABLE_DMABUF_RENDERER=1` & `WEBKIT_DISABLE_COMPOSITING_MODE=1`
     sebelum WebKit diinisialisasi.
  2. Race condition: window sebelumnya memuat URL agent sekali saja tanpa
     retry — kalau server Flask belum sempat nyala saat VM baru boot
     (jaringan/servis masih "pemanasan"), window gagal memuat dan terlihat
     kosong selamanya. Diperbaiki: window kini dibuka dengan halaman loading
     lokal instan (tidak butuh server), lalu background thread menunggu UI
     siap (timeout dinaikkan 40s -> 120s) baru mengalihkan window ke URL asli.
     Kalau tetap gagal, tampil halaman error yang jelas (bukan blank).

### Changed
- **Branding di web portal**: logo placeholder (`◈`) di leaderboard & admin
  console diganti dengan logo abilithic sungguhan (`web/public/blueforge-icon-256.png`,
  disalin dari `assets/blueforge-icon-256.png`), juga dipakai sebagai favicon
  (`web/app/layout.tsx`). Nama sesi default saat buat lomba baru diubah dari
  "Lomba DHC #1" menjadi "Defense Hardening Competition #1"
  (`web/app/admin/page.tsx`).

### Fixed
- **Soal `telnet_disabled` bisa "PASS sendiri" tanpa peserta berbuat apa-apa**:
  provisioning lama bergantung pada paket `telnetd`/`inetd`, yang sudah tak
  bisa diandalkan (sering gagal terpasang / tak bisa jalan lewat systemd) di
  Ubuntu modern — kalau gagal, tidak pernah ada apa pun yang listen di port
  23, jadi soal ini otomatis lolos sejak awal. Diganti listener TCP minimal
  buatan sendiri, tanpa dependensi paket telnet apa pun: `image/build/dhc-telnetd.py`
  (service) + `image/build/dhc-telnetd.service` (unit systemd), dipasang &
  diaktifkan oleh `provision.sh`. Peserta mematikan dengan
  `sudo systemctl disable --now dhc-telnetd`. Hint di database
  (`db/seed/difficulties.sql`, `agent/checks/telnet_disabled/manifest.yaml`)
  & kunci jawaban internal diperbarui mengikuti.
- **`provision.sh` sekarang dua fase (RESET lalu PLANT)**: sebelum menanam 15
  celah, skrip lebih dulu membersihkan sisa provisioning/percobaan
  sebelumnya — hapus user rogue lama, `ufw --force reset`, lepas mask/disable
  `dhc-telnetd`, dan buang override `net.ipv4.ip_forward` yang mungkin
  ter-persist ke `/etc/sysctl.conf`/`/etc/sysctl.d/` saat peserta melakukan
  fix. Ini membuat provisioning deterministik walau dijalankan berkali-kali
  di VM yang sama (skenario umum saat testing berulang sebelum lomba
  sesungguhnya).
- **Akar masalah "poin/timestamp tidak update otomatis"**: agent kini
  menyinkronkan jam ke server (`GET /api/v1/time`, tanpa signing) sebelum
  setiap siklus, lalu mengoreksi timestamp HMAC-nya dengan offset itu
  (`agent/crypto/signing.py`, `agent/network/client.py`). Sebelumnya, agent
  menandatangani request dengan jam lokal VM mentah; VM hasil clone/template
  VMware yang jamnya meleset >5 menit (jendela toleransi server) membuat
  semua request ditolak diam-diam sampai jam VM dikoreksi manual. Timer
  countdown, `computed_at_ms` skor, dan `taken_at_server_ms` snapshot ikut
  dikoreksi (`agent/main.py`, `agent/snapshot/manager.py`). Lihat
  `docs/REVIEW-AND-CONCEPT-v2.md` §2 untuk diagnosis lengkap. Test regresi:
  `tests/test_clock_skew.py`.
- **Admin console tidak auto-refresh**: daftar sesi & peserta kini polling
  otomatis (5s / 4s) alih-alih menunggu reload manual (`web/app/admin/page.tsx`).

### Added (v0.2 — dalam progres)
- **Web console pro**: login persisten (sesi cookie httpOnly), kelola event
  (hapus/arsip sesi), kelola peserta (daftar, diskualifikasi, hapus), redesain UI
  (branding, badge status, medali, toast, loading/empty state).
- **Agent kiosk**: `kiosk.py` menampilkan agent sebagai aplikasi fullscreen
  (pywebview + fallback browser-kiosk), autostart `.desktop`, `install-kiosk.sh`,
  UI lokal dipoles. Peserta zero-setup: boot VM → app muncul otomatis.

- **15 check** (dari 5): +passwd_perm, empty_password_removed, uid0_unique,
  ip_forward_disabled, password_max_days, ssh_permitempty_disabled,
  world_writable_removed, suid_bash_removed, rogue_sudo_removed, cron_backdoor_removed.
- **Tingkat berbeda nyata**: Easy 6 soal · Medium 11 · Hard 15 (subset di seed).
- **Custom timer** saat buat sesi (menit), default per tingkat.
- **Batalkan diskualifikasi** (requalify) di admin.
- Kiosk jadi **jendela companion** (bukan fullscreen-lock) agar peserta bisa pakai terminal.
- **Indikator koneksi** (titik hijau/kuning/merah) + tombol **"Sinkron sekarang"** di panel
  peserta → paksa agent poll ke server tanpa nunggu interval.
- `run-agent.sh`: jalankan agent bersih (auto-bunuh proses lama di port 8080).

### Changed
- Admin auth pindah dari header password ke sesi cookie (lib/auth.ts).
- `provision.sh` menanam **15 celah**; seed pakai UPSERT (aman dijalankan ulang).
- UI leaderboard/admin/kiosk dipoles: indikator "Live", skeleton loading,
  micro-interaction hover/transisi, highlight juara #1 (`web/app/globals.css`,
  `web/app/page.tsx`, `web/app/admin/page.tsx`, `agent/ui/templates/index.html`).
- README ditulis ulang mengikuti pola Fathom & Flare
  (badge, hero, screenshots, footer branding); tambah `DISCLAIMER.md` dan
  `assets/README.md`.
- **Port lokal kiosk/agent: `8080` → `9090`** (`agent/config.example.yaml`,
  `agent/kiosk.py`, `agent/main.py`, `agent/ui/server.py`, `agent/run-agent.sh`,
  `README.md`, `docs/setup-participant.md`, `docs/DEPLOYMENT-GUIDE.md`) — 8080
  lazim dipakai proxy Burp Suite/OWASP ZAP di mesin tester, jadi dihindari agar
  agent bisa jalan berdampingan dengan alat itu di komputer yang sama. Entri
  changelog historis di atas (v0.1/v0.2) sengaja tidak diubah.
- **Reorganisasi dokumen untuk presentasi GitHub yang lebih profesional**:
  - `KONSEP-BlueForge.md` (TDD asli, sebelumnya hidup di
    luar repo git dan tak pernah ter-upload) dipindahkan ke dalam repo sebagai
    `docs/TECHNICAL-DESIGN.md`.
  - `REVIEW-DAN-KONSEP-v2.md` (root, nama campur bahasa) → `docs/REVIEW-AND-CONCEPT-v2.md`.
  - `PANDUAN-SETUP-v0.1.md` (root) → `docs/DEPLOYMENT-GUIDE.md`, disunting agar
    tak lagi menyebut "v0.1"/"5 celah" (sudah 15 celah & 3 tingkat sejak v0.2).
  - Root repo kini hanya berisi file governance standar GitHub (README, LICENSE,
    CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, DISCLAIMER, CHANGELOG); seluruh
    dokumen teknis/naratif panjang ada di `docs/`.

## [0.1.0] — 2026-06-30
### Added
- **Database**: schema Postgres (competitions, participants, checks, difficulties,
  participant_checks, scores, snapshots, event_logs, nonces) + view `leaderboard`.
- **Seed**: preset tingkat Easy/Medium/Hard + 5 check Linux dasar
  (ssh_root_disabled, ufw_enabled, telnet_disabled, rogue_user_removed, shadow_perm).
- **Agent (Python)**: arsitektur modular — state_manager, score_engine (pure fn),
  check_runner, network client + retry/backoff + store-and-forward, snapshot manager,
  crypto HMAC signing, logger terstruktur, local UI (localhost:8080).
- **Web (Next.js)**: API `/v1` (register, state, score, heartbeat, snapshot, admin),
  leaderboard realtime (Supabase Realtime), halaman admin START/PAUSE/STOP.
- **Baseline & Evidence**: snapshot registration/start/stop + eligibility anti pre-fix.
- **Governance**: README, LICENSE (MIT), CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, ADR-001..006.
- **CI**: GitHub Actions (lint + unit test scoring).

[Unreleased]: https://github.com/n0xnull/BlueForge/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/n0xnull/BlueForge/releases/tag/v0.1.0
