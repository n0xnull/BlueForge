-- =====================================================================
-- BlueForge — Seed data (v0.4)
-- 30 check Linux (15 lama + 15 baru) + preset tingkat:
--   Easy 6 / Medium 11 / Hard 15 (TIDAK berubah dari v0.2/v0.3 -- tetap
--   dipakai untuk sesi latihan) + preset baru "fitcom" (30 soal, semua
--   check, durasi default 2 jam 30 menit) khusus lomba FITCOM Univ.
--   Dinamika.
--
-- Hint (v0.4): field `hint_advanced` (command jawaban langsung) SUDAH
-- TIDAK DIPAKAI SAMA SEKALI -- lihat agent/runner/check_runner.py. Hanya
-- ~25% soal (8 dari 30) yang punya `hint_basic` sama sekali; hint yang ada
-- SENGAJA hanya mengarahkan (guiding), bukan jawaban. Kolom `hint_advanced`
-- tetap ada di schema untuk kompatibilitas tapi selalu di-null-kan di sini.
--
-- AMAN dijalankan ulang: memakai UPSERT (on conflict do update),
-- jadi menjalankan lagi akan MEMPERBARUI check & preset yang sudah ada.
-- Jalankan SETELAH schema.sql (dan db/migrations/0002_fitcom_preset.sql
-- kalau database sudah lama ada / sudah pernah di-seed versi sebelumnya).
-- =====================================================================

-- ---------------- 30 CHECK ----------------
insert into checks (code, title, description, points, is_penalty, must_stay_passing, category, hint_basic, hint_advanced, difficulty_tags) values
  -- ===== 15 check lama (v0.2/v0.3) — deskripsi/poin TIDAK berubah =====
  ('ssh_root_disabled','Nonaktifkan Login Root melalui SSH','Konfigurasi SSH tidak boleh mengizinkan autentikasi root secara langsung; parameter PermitRootLogin pada /etc/ssh/sshd_config harus bernilai "no".',10,false,false,'ssh',
    'Login root langsung lewat SSH kemungkinan masih diizinkan. Periksa parameter terkait login root di berkas konfigurasi SSH daemon, lalu pastikan service SSH membaca ulang konfigurasi setelah diubah.',null,'["easy","medium","hard","fitcom"]'),
  ('ufw_enabled','Aktifkan Firewall UFW','Firewall UFW pada sistem harus dalam status aktif (active) untuk menyaring lalu lintas jaringan yang masuk.',10,false,false,'firewall',
    null,null,'["easy","medium","hard","fitcom"]'),
  ('telnet_disabled','Nonaktifkan Layanan Telnet','Tidak boleh terdapat layanan yang listening pada port TCP 23 (Telnet), mengingat protokol ini mengirimkan kredensial dalam bentuk plaintext.',10,false,false,'service',
    'Ada layanan yang masih mendengarkan koneksi di port Telnet (23). Telusuri layanan apa yang aktif di port tersebut, lalu nonaktifkan secara permanen lewat manajer service (bukan cuma dihentikan sesaat, supaya tidak otomatis menyala lagi).',null,'["easy","medium","hard","fitcom"]'),
  ('rogue_user_removed','Hapus Akun Pengguna Tidak Sah','Akun pengguna mencurigakan "hacker" harus dihapus sepenuhnya dari sistem.',10,false,false,'account',
    null,null,'["easy","medium","hard","fitcom"]'),
  ('shadow_perm','Perbaiki Izin Akses Berkas /etc/shadow','Berkas /etc/shadow tidak boleh dapat dibaca oleh pengguna lain (world-readable); izin akses yang benar adalah mode 640 atau yang lebih ketat.',10,false,false,'permission',
    null,null,'["easy","medium","hard","fitcom"]'),
  ('passwd_perm','Perbaiki Izin Akses Berkas /etc/passwd','Berkas /etc/passwd tidak boleh dapat ditulis oleh grup maupun pengguna lain; izin akses yang benar adalah mode 644.',10,false,false,'permission',
    null,null,'["easy","medium","hard","fitcom"]'),
  ('empty_password_removed','Hapus Akun dengan Kata Sandi Kosong','Tidak boleh terdapat akun login dengan kata sandi kosong pada berkas /etc/shadow.',10,false,false,'account',
    'Cari akun pengguna dengan kolom kata sandi yang BENAR-BENAR kosong di berkas kredensial sistem. Setelah kamu perbaiki, pastikan kolom itu betul-betul tidak kosong lagi -- sebagian cara mengunci akun tidak selalu mengubah kolom ini kalau sebelumnya memang kosong.',null,'["medium","hard","fitcom"]'),
  ('uid0_unique','Pastikan Hanya Root yang Memiliki UID 0','Tidak boleh ada akun selain root yang memiliki User ID (UID) bernilai 0, karena hal tersebut setara dengan hak akses root.',10,false,false,'account',
    'Cari akun lain (selain root) yang memiliki User ID setara root. Saat mencoba menghapusnya, kamu mungkin ditolak dengan alasan akun ''sedang digunakan'' -- itu bukan error sungguhan, itu terjadi karena UID-nya kembar dengan root; cari opsi pada perintah penghapusan user yang bisa memaksa (force) melewati pengecekan itu.',null,'["medium","hard","fitcom"]'),
  ('ip_forward_disabled','Nonaktifkan IP Forwarding','Parameter kernel net.ipv4.ip_forward harus bernilai 0, karena sistem peserta bukan merupakan router dan tidak boleh meneruskan paket antar-jaringan.',10,false,false,'network',
    null,null,'["medium","hard","fitcom"]'),
  ('password_max_days','Terapkan Batas Masa Berlaku Kata Sandi','Nilai PASS_MAX_DAYS pada /etc/login.defs harus 365 hari atau kurang, agar kata sandi wajib diperbarui secara berkala.',10,false,false,'policy',
    null,null,'["medium","hard","fitcom"]'),
  ('ssh_permitempty_disabled','Larang Autentikasi SSH dengan Kata Sandi Kosong','Konfigurasi SSH tidak boleh mengizinkan login dengan kata sandi kosong; parameter PermitEmptyPasswords harus bernilai "no".',10,false,false,'ssh',
    null,null,'["medium","hard","fitcom"]'),
  ('world_writable_removed','Amankan Berkas yang Dapat Ditulis oleh Semua Pengguna','Berkas /opt/dhc/secret.txt tidak boleh dapat ditulis oleh pengguna lain (world-writable).',10,false,false,'permission',
    null,null,'["hard","fitcom"]'),
  ('suid_bash_removed','Hapus Shell Backdoor Berbit SUID','Salinan shell berbit SUID pada /usr/local/bin/rootbash merupakan backdoor yang memberikan hak akses root secara instan dan harus dihapus.',10,false,false,'privilege',
    null,null,'["hard","fitcom"]'),
  ('rogue_sudo_removed','Cabut Hak Akses Sudo yang Tidak Sah','Akun "backdoor" tidak boleh menjadi anggota grup sudo.',10,false,false,'privilege',
    null,null,'["hard","fitcom"]'),
  ('cron_backdoor_removed','Hapus Cron Job Backdoor','Berkas terjadwal /etc/cron.d/dhc-backdoor merupakan mekanisme persistence yang tidak sah dan harus dihapus.',10,false,false,'persistence',
    null,null,'["hard","fitcom"]'),
  -- ===== 15 check baru (v0.4) =====
  ('ftp_disabled','Nonaktifkan Layanan FTP Palsu','Tidak boleh terdapat layanan yang listening pada port TCP 21 (FTP), mengingat protokol FTP standar mengirimkan kredensial dalam bentuk plaintext.',10,false,false,'service',
    null,null,'["fitcom"]'),
  ('ssh_x11_forwarding_disabled','Nonaktifkan X11 Forwarding SSH','Konfigurasi SSH tidak boleh mengizinkan X11 forwarding; parameter X11Forwarding pada /etc/ssh/sshd_config harus bernilai "no".',10,false,false,'ssh',
    null,null,'["fitcom"]'),
  ('tmp_sticky_bit_set','Pasang Kembali Sticky Bit pada /tmp','Direktori /tmp harus memiliki sticky bit aktif agar pengguna tidak dapat menghapus atau mengganti nama berkas milik pengguna lain di direktori bersama tersebut.',10,false,false,'permission',
    null,null,'["fitcom"]'),
  ('password_min_days_set','Terapkan Batas Minimum Pergantian Kata Sandi','Nilai PASS_MIN_DAYS pada /etc/login.defs harus minimal 1 hari, agar pengguna tidak dapat langsung mengganti kata sandi berkali-kali untuk menghindari kebijakan riwayat password.',10,false,false,'policy',
    null,null,'["fitcom"]'),
  ('ssh_max_auth_tries_limited','Batasi Percobaan Autentikasi SSH (MaxAuthTries)','Nilai MaxAuthTries pada konfigurasi SSH harus 4 atau kurang, untuk membatasi jumlah percobaan login gagal sebelum koneksi diputus (mitigasi brute force).',10,false,false,'ssh',
    null,null,'["fitcom"]'),
  ('syn_cookies_enabled','Aktifkan Perlindungan SYN Cookies','Parameter kernel net.ipv4.tcp_syncookies harus bernilai 1, untuk melindungi sistem dari serangan SYN flood (DoS) yang menghabiskan tabel koneksi.',10,false,false,'network',
    null,null,'["fitcom"]'),
  ('aslr_enabled','Aktifkan ASLR Penuh (Address Space Layout Randomization)','Parameter kernel kernel.randomize_va_space harus bernilai 2 (ASLR penuh), agar lokasi memori proses diacak sehingga mempersulit eksploitasi buffer overflow.',10,false,false,'kernel',
    null,null,'["fitcom"]'),
  ('icmp_redirects_disabled','Nonaktifkan Penerimaan ICMP Redirect','Parameter kernel net.ipv4.conf.all.accept_redirects harus bernilai 0, agar sistem tidak menerima pengalihan rute (ICMP redirect) dari host lain di jaringan yang dapat dipakai untuk serangan man-in-the-middle.',10,false,false,'network',
    null,null,'["fitcom"]'),
  ('source_routing_disabled','Nonaktifkan Source Routing','Parameter kernel net.ipv4.conf.all.accept_source_route harus bernilai 0, agar sistem menolak paket dengan rute sumber (source-routed packets) yang dapat dipakai untuk melewati kontrol jaringan.',10,false,false,'network',
    null,null,'["fitcom"]'),
  ('core_dump_restricted','Nonaktifkan Core Dump untuk Program SUID','Parameter kernel fs.suid_dumpable harus bernilai 0, agar program dengan bit SUID tidak menghasilkan core dump yang berpotensi membocorkan data sensitif di memori (termasuk kredensial).',10,false,false,'kernel',
    null,null,'["fitcom"]'),
  ('unsafe_path_removed','Hapus Direktori Tidak Aman dari PATH Sistem','Variabel PATH global (system-wide) tidak boleh menyertakan direktori yang dapat ditulis oleh sembarang pengguna (seperti direktori kerja saat ini "."), karena hal ini memungkinkan serangan PATH hijacking terhadap perintah yang dijalankan pengguna lain, termasuk root.',10,false,false,'permission',
    'Salah satu berkas konfigurasi shell/login menambahkan direktori yang bisa ditulis siapa saja ke dalam variabel PATH -- ini bisa dieksploitasi untuk menjalankan program palsu saat user lain (termasuk root) memanggil perintah umum. Telusuri berkas konfigurasi profil/login system-wide (bukan punya satu user saja).',null,'["fitcom"]'),
  ('rogue_crontab_removed','Hapus Cron Job Pribadi yang Mencurigakan','Selain /etc/cron.d, setiap pengguna dapat memiliki jadwal cron miliknya sendiri (per-user crontab). Akun layanan "svc-backup" memiliki jadwal cron mencurigakan yang harus dihapus.',10,false,false,'persistence',
    'Bukan cuma /etc/cron.d yang bisa menjadwalkan tugas -- setiap akun user juga bisa punya jadwal cron miliknya sendiri (per-user crontab). Periksa apakah salah satu akun di sistem (bukan akunmu sendiri) punya jadwal cron pribadi yang mencurigakan.',null,'["fitcom"]'),
  ('cron_writable_script_removed','Amankan Script yang Dijalankan Cron sebagai Root','Tugas terjadwal /etc/cron.d/dhc-backup menjalankan script /opt/dhc/backup.sh sebagai root. Script tersebut saat ini dapat ditulis oleh sembarang pengguna (world-writable), sehingga siapa pun bisa menyisipkan perintah dan mendapat eksekusi sebagai root. Perbaiki izin akses script tersebut (atau hapus mekanisme cron-nya).',10,false,false,'persistence',
    'Ada tugas terjadwal (cron) yang menjalankan sebuah script sebagai root -- masalahnya bukan pada jadwalnya, tapi pada IZIN AKSES script yang dijalankan itu. Periksa siapa saja yang boleh MENULIS ke script tersebut.',null,'["fitcom"]'),
  ('duplicate_uid_removed','Hapus Akun dengan UID Kembar (Duplicate UID)','Setiap akun pengguna (selain root) harus memiliki UID yang unik. Ditemukan dua akun berbeda yang berbagi UID yang sama, artinya keduanya punya hak akses identik di level sistem -- salah satunya harus dihapus.',10,false,false,'account',
    'UID (User ID) semestinya unik per akun. Periksa apakah ada dua akun berbeda di /etc/passwd yang diam-diam berbagi UID yang sama (selain root) -- itu artinya keduanya punya hak akses identik di level sistem.',null,'["fitcom"]'),
  ('backdoor_listener_removed','Hapus Listener Backdoor Tersembunyi','Ditemukan proses yang membuka listener jaringan mencurigakan pada port TCP 4444 (port yang lazim dipakai payload reverse shell), berjalan sebagai layanan tersembunyi. Layanan ini harus dihentikan dan dinonaktifkan secara permanen.',10,false,false,'persistence',
    null,null,'["fitcom"]')
on conflict (code) do update set
  title=excluded.title, description=excluded.description, points=excluded.points,
  is_penalty=excluded.is_penalty, must_stay_passing=excluded.must_stay_passing,
  category=excluded.category, hint_basic=excluded.hint_basic,
  hint_advanced=excluded.hint_advanced, difficulty_tags=excluded.difficulty_tags;

-- ---------------- PRESET TINGKAT (subset berbeda) ----------------
-- Easy/Medium/Hard TIDAK berubah dari v0.2/v0.3 (tetap 6/11/15 soal lama)
-- -- masih dipakai untuk sesi latihan. Preset "fitcom" (BARU, v0.4) dipakai
-- untuk lomba FITCOM sungguhan: semua 30 soal, durasi 2 jam 30 menit.
--
-- Urutan array active_check_codes = urutan No.1..No.30 yang BENAR-BENAR
-- ditampilkan ke peserta (kiosk agent & panel admin keduanya me-render
-- checks persis sesuai urutan array ini -- lihat agent/main.py
-- status_snapshot() & web/app/admin/page.tsx). Karena itu urutan di sini
-- BUKAN sekadar estetika, ini kontrak urutan soal.
--
-- Pita kesulitan preset "fitcom" (v0.4):
--   No. 1-11  : setara Easy  -- edit satu baris config / hapus satu akun
--   No. 12-21 : setara Medium -- kombinasi beberapa file / sysctl kernel
--   No. 22-30 : setara Hard  -- perlu investigasi/penemuan (proses/cron/
--               user tersembunyi), termasuk 4 dari 5 soal baru yang
--               dapat hint guiding dan No.30 (backdoor_listener_removed)
--               yang sengaja TANPA hint sama sekali.
insert into difficulties (key, name, description, active_check_codes, hint_policy, penalty_weight, default_duration_sec) values
  ('easy','Mudah','Lomba perdana/pemula. 6 soal dasar, hint lengkap, penalti ringan.',
    '["ssh_root_disabled","ufw_enabled","telnet_disabled","rogue_user_removed","shadow_perm","passwd_perm"]',
    'full', 0.5, 7200),
  ('medium','Medium','Peserta terbiasa. 11 soal, hint terbatas, penalti standar.',
    '["ssh_root_disabled","ufw_enabled","telnet_disabled","rogue_user_removed","shadow_perm","passwd_perm","empty_password_removed","uid0_unique","ip_forward_disabled","password_max_days","ssh_permitempty_disabled"]',
    'limited', 1.0, 5400),
  ('hard','Hard','Peserta mahir. 15 soal (termasuk backdoor tersembunyi), hint minim, penalti berat.',
    '["ssh_root_disabled","ufw_enabled","telnet_disabled","rogue_user_removed","shadow_perm","passwd_perm","empty_password_removed","uid0_unique","ip_forward_disabled","password_max_days","ssh_permitempty_disabled","world_writable_removed","suid_bash_removed","rogue_sudo_removed","cron_backdoor_removed"]',
    'none', 1.5, 3600),
  ('fitcom','FITCOM','Preset lomba FITCOM Universitas Dinamika. 30 soal (superset penuh, urut mudah->sulit), hint guiding utk ~25% soal saja, durasi default 2 jam 30 menit.',
    '["ssh_root_disabled","ufw_enabled","telnet_disabled","ftp_disabled","rogue_user_removed","shadow_perm","passwd_perm","tmp_sticky_bit_set","ssh_x11_forwarding_disabled","ssh_max_auth_tries_limited","password_min_days_set","empty_password_removed","uid0_unique","ip_forward_disabled","password_max_days","ssh_permitempty_disabled","syn_cookies_enabled","icmp_redirects_disabled","source_routing_disabled","aslr_enabled","core_dump_restricted","world_writable_removed","suid_bash_removed","rogue_sudo_removed","cron_backdoor_removed","duplicate_uid_removed","rogue_crontab_removed","cron_writable_script_removed","unsafe_path_removed","backdoor_listener_removed"]',
    'full', 1.0, 9000)
on conflict (key) do update set
  name=excluded.name, description=excluded.description,
  active_check_codes=excluded.active_check_codes, hint_policy=excluded.hint_policy,
  penalty_weight=excluded.penalty_weight, default_duration_sec=excluded.default_duration_sec;
