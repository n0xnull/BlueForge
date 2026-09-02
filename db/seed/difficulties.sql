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
  ('ssh_root_disabled','Nonaktifkan Login Root melalui SSH','Konfigurasi layanan SSH harus diamankan agar tidak mengizinkan autentikasi langsung sebagai pengguna superuser (root).',10,false,false,'ssh',
    'Periksa berkas konfigurasi SSH daemon untuk opsi pembatasan login root. Setelah diubah, pastikan layanan membaca ulang konfigurasi.',null,'["easy","medium","hard","fitcom"]'),
  ('ufw_enabled','Aktifkan Firewall UFW','Sistem harus dilindungi oleh firewall internal yang aktif untuk menyaring dan membatasi lalu lintas jaringan masuk.',10,false,false,'firewall',
    'Aktifkan firewall dengan perintah ''ufw enable'' dan pastikan statusnya ''active'' via ''ufw status''.',null,'["easy","medium","hard","fitcom"]'),
  ('telnet_disabled','Nonaktifkan Layanan Telnet','Layanan komunikasi teks tanpa enkripsi (Telnet) tidak boleh aktif mendengarkan koneksi pada port standar.',10,false,false,'service',
    null,null,'["easy","medium","hard","fitcom"]'),
  ('rogue_user_removed','Hapus Akun Pengguna Tidak Sah','Akun pengguna yang tidak dikenal atau mencurigakan harus dihapus sepenuhnya dari daftar pengguna sistem.',10,false,false,'account',
    null,null,'["easy","medium","hard","fitcom"]'),
  ('shadow_perm','Perbaiki Izin Akses Berkas /etc/shadow','Berkas enkripsi kata sandi sistem (/etc/shadow) harus dibatasi izin aksesnya agar tidak dapat dibaca oleh pengguna umum.',10,false,false,'permission',
    'Gunakan perintah ''chmod 640 /etc/shadow'' atau ''chmod o-rwx /etc/shadow'' untuk mencabut izin akses world-readable.',null,'["easy","medium","hard","fitcom"]'),
  ('passwd_perm','Perbaiki Izin Akses Berkas /etc/passwd','Berkas daftar akun sistem (/etc/passwd) tidak boleh dapat diubah atau ditulis oleh pengguna selain root.',10,false,false,'permission',
    null,null,'["easy","medium","hard","fitcom"]'),
  ('empty_password_removed','Hapus Akun dengan Kata Sandi Kosong','Setiap akun pengguna yang terdaftar di sistem wajib memiliki kata sandi atau dalam status terkunci (tidak boleh kosong).',10,false,false,'account',
    'Telusuri berkas kredensial sistem untuk menemukan akun tanpa hash kata sandi. Kunci akun tersebut atau tetapkan kata sandi yang valid.',null,'["medium","hard","fitcom"]'),
  ('uid0_unique','Pastikan Hanya Root yang Memiliki UID 0','Tidak boleh terdapat akun pengguna biasa yang berbagi User ID (UID 0) dengan akun superuser (root).',10,false,false,'account',
    null,null,'["medium","hard","fitcom"]'),
  ('root_home_perm','Amankan Izin Akses Direktori Home Root','Direktori rumah pengelola utama (/root) harus dibatasi izin aksesnya agar tidak dapat diakses, dibaca, atau diubah oleh pengguna lain.',10,false,false,'permission',
    'Gunakan perintah ''chmod 700 /root'' atau ''chmod 750 /root'' untuk mencabut hak akses publik/others pada direktori rumah root.',null,'["medium","hard","fitcom"]'),
  ('password_max_days','Terapkan Batas Masa Berlaku Kata Sandi','Kebijakan usia kata sandi sistem harus membatasi masa berlaku maksimum penggunaan kata sandi (maksimal 1 tahun).',10,false,false,'policy',
    null,null,'["medium","hard","fitcom"]'),
  ('ssh_permitempty_disabled','Larang Autentikasi SSH dengan Kata Sandi Kosong','Konfigurasi layanan SSH harus menolak percobaan login autentikasi bagi akun tanpa kata sandi.',10,false,false,'ssh',
    null,null,'["medium","hard","fitcom"]'),
  ('world_writable_removed','Amankan Berkas yang Dapat Ditulis oleh Semua Pengguna','Berkas rahasia di direktori aplikasi (/opt/dhc/secret.txt) tidak boleh memiliki izin tulis untuk publik (world-writable).',10,false,false,'permission',
    null,null,'["hard","fitcom"]'),
  ('suid_bash_removed','Hapus Shell Backdoor Berbit SUID','Berkas eksekusi shell berhak akses istimewa (SUID binary) yang tidak sah di sistem harus ditemukan dan dihapus.',10,false,false,'privilege',
    null,null,'["hard","fitcom"]'),
  ('rogue_sudo_removed','Cabut Hak Akses Sudo yang Tidak Sah','Akun yang tidak berhak tidak boleh memiliki hak akses administratif melalui grup sudo.',10,false,false,'privilege',
    null,null,'["hard","fitcom"]'),
  ('cron_backdoor_removed','Hapus Cron Job Backdoor','Jadwal tugas otomatis (cron job) yang mencurigakan di direktori cron sistem harus dibersihkan.',10,false,false,'persistence',
    null,null,'["hard","fitcom"]'),
  ('ftp_disabled','Nonaktifkan Layanan FTP Palsu','Layanan mentransfer berkas tanpa enkripsi (FTP) tidak boleh aktif mendengarkan koneksi pada port standar.',10,false,false,'service',
    null,null,'["fitcom"]'),
  ('ssh_x11_forwarding_disabled','Nonaktifkan X11 Forwarding SSH','Fitur penerusan antarmuka grafis (X11 Forwarding) pada SSH harus dinonaktifkan untuk mencegah potensi pencurian sesi tampilan.',10,false,false,'ssh',
    null,null,'["fitcom"]'),
  ('tmp_sticky_bit_set','Pasang Kembali Sticky Bit pada /tmp','Direktori penyimpanan sementara (/tmp) harus memiliki atribut sticky bit aktif demi mencegah pengrusakan berkas antar pengguna.',10,false,false,'permission',
    null,null,'["fitcom"]'),
  ('password_min_days_set','Terapkan Batas Minimum Pergantian Kata Sandi','Kebijakan kata sandi harus menetapkan batas waktu minimum antar perubahan kata sandi untuk mencegah manipulasi riwayat kata sandi.',10,false,false,'policy',
    null,null,'["fitcom"]'),
  ('ssh_max_auth_tries_limited','Batasi Percobaan Autentikasi SSH (MaxAuthTries)','Layanan SSH harus membatasi batas maksimum percobaan autentikasi gagal per sesi untuk memitigasi serangan brute force.',10,false,false,'ssh',
    'Batasi jumlah percobaan autentikasi SSH pada konfigurasi daemon untuk memitigasi brute force.',null,'["fitcom"]'),
  ('syn_cookies_enabled','Aktifkan Perlindungan SYN Cookies','Fitur perlindungan kernel terhadap serangan banjir jaringan (SYN Flood DoS) harus diaktifkan.',10,false,false,'network',
    null,null,'["fitcom"]'),
  ('aslr_enabled','Aktifkan ASLR Penuh (Address Space Layout Randomization)','Fitur acak alokasi ruang memori (ASLR) pada kernel harus dikonfigurasikan pada tingkat perlindungan penuh.',10,false,false,'kernel',
    'Periksa parameter kernel sysctl yang mengatur pengacakan alokasi ruang memori (Virtual Address space).',null,'["fitcom"]'),
  ('icmp_redirects_disabled','Nonaktifkan Penerimaan ICMP Redirect','Sistem harus menolak pesan pengalihan rute ICMP (ICMP Redirects) guna mencegah manipulasi tabel routing oleh pihak ketiga.',10,false,false,'network',
    null,null,'["fitcom"]'),
  ('source_routing_disabled','Nonaktifkan Source Routing','Paket jaringan dengan penentuan rute sumber (Source-Routed Packets) harus ditolak oleh kernel sistem.',10,false,false,'network',
    null,null,'["fitcom"]'),
  ('core_dump_restricted','Nonaktifkan Core Dump untuk Program SUID','Pembuatan berkas memori (core dump) untuk program berpemberian hak khusus (SUID) harus dibatasi.',10,false,false,'kernel',
    null,null,'["fitcom"]'),
  ('unsafe_path_removed','Hapus Direktori Tidak Aman dari PATH Sistem','Variabel jalur pencarian eksekusi global (PATH) tidak boleh memuat direktori kerja relatif atau direktori yang dapat diubah sembarang pengguna.',10,false,false,'permission',
    'Telusuri berkas konfigurasi profil/login global (/etc/profile, /etc/environment, dll) untuk menemukan penyisipan titik (.) atau jalur tidak aman pada variabel PATH.',null,'["fitcom"]'),
  ('rogue_crontab_removed','Hapus Cron Job Pribadi yang Mencurigakan','Jadwal tugas pribadi (per-user crontab) pada akun layanan yang tidak sah harus dibersihkan dari sistem.',10,false,false,'persistence',
    null,null,'["fitcom"]'),
  ('cron_writable_script_removed','Amankan Script yang Dijalankan Cron sebagai Root','Naskah otomatis (script) yang dijalankan secara berkala dengan hak akses root tidak boleh dapat diubah atau ditulis oleh pengguna biasa.',10,false,false,'persistence',
    'Periksa berkas skrip yang dipanggil oleh tugas terjadwal root. Masalahnya ada pada hak akses tulis publik (world-writable) skrip tersebut.',null,'["fitcom"]'),
  ('duplicate_uid_removed','Hapus Akun dengan UID Kembar (Duplicate UID)','Setiap akun pengguna pada sistem harus memiliki pengenal numerik unik (UID), tidak boleh ada dua akun yang berbagi UID yang sama.',10,false,false,'account',
    null,null,'["fitcom"]'),
  ('backdoor_listener_removed','Hapus Listener Backdoor Tersembunyi','Proses tidak dikenal yang mendengarkan koneksi jaringan (backdoor listener) harus dihentikan dan dicegah agar tidak berjalan kembali.',10,false,false,'persistence',
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
    '["ssh_root_disabled","ufw_enabled","telnet_disabled","rogue_user_removed","shadow_perm","passwd_perm","empty_password_removed","uid0_unique","root_home_perm","password_max_days","ssh_permitempty_disabled"]',
    'limited', 1.0, 5400),
  ('hard','Hard','Peserta mahir. 15 soal (termasuk backdoor tersembunyi), hint minim, penalti berat.',
    '["ssh_root_disabled","ufw_enabled","telnet_disabled","rogue_user_removed","shadow_perm","passwd_perm","empty_password_removed","uid0_unique","root_home_perm","password_max_days","ssh_permitempty_disabled","world_writable_removed","suid_bash_removed","rogue_sudo_removed","cron_backdoor_removed"]',
    'none', 1.5, 3600),
  ('fitcom','FITCOM','Preset lomba FITCOM Universitas Dinamika. 30 soal (superset penuh, urut mudah->sulit), hint guiding utk ~25% soal saja, durasi default 2 jam 30 menit.',
    '["ssh_root_disabled","ufw_enabled","telnet_disabled","ftp_disabled","rogue_user_removed","shadow_perm","passwd_perm","tmp_sticky_bit_set","ssh_x11_forwarding_disabled","ssh_max_auth_tries_limited","password_min_days_set","empty_password_removed","uid0_unique","root_home_perm","password_max_days","ssh_permitempty_disabled","syn_cookies_enabled","icmp_redirects_disabled","source_routing_disabled","aslr_enabled","core_dump_restricted","world_writable_removed","suid_bash_removed","rogue_sudo_removed","cron_backdoor_removed","duplicate_uid_removed","rogue_crontab_removed","cron_writable_script_removed","unsafe_path_removed","backdoor_listener_removed"]',
    'full', 1.0, 9000)
on conflict (key) do update set
  name=excluded.name, description=excluded.description,
  active_check_codes=excluded.active_check_codes, hint_policy=excluded.hint_policy,
  penalty_weight=excluded.penalty_weight, default_duration_sec=excluded.default_duration_sec;
