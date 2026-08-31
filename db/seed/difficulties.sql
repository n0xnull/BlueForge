-- =====================================================================
-- BlueForge — Seed data (v0.2)
-- 15 check Linux + preset tingkat (Easy 6 / Medium 11 / Hard 15).
-- AMAN dijalankan ulang: memakai UPSERT (on conflict do update),
-- jadi menjalankan lagi akan MEMPERBARUI check & preset yang sudah ada.
-- Jalankan SETELAH schema.sql.
-- =====================================================================

-- ---------------- 15 CHECK ----------------
insert into checks (code, title, description, points, is_penalty, must_stay_passing, category, hint_basic, hint_advanced, difficulty_tags) values
  ('ssh_root_disabled','Nonaktifkan Login Root melalui SSH','Konfigurasi SSH tidak boleh mengizinkan autentikasi root secara langsung; parameter PermitRootLogin pada /etc/ssh/sshd_config harus bernilai "no".',10,false,false,'ssh',
    'Periksa /etc/ssh/sshd_config baris PermitRootLogin.','Set "PermitRootLogin no" lalu: sudo systemctl restart ssh','["easy","medium","hard"]'),
  ('ufw_enabled','Aktifkan Firewall UFW','Firewall UFW pada sistem harus dalam status aktif (active) untuk menyaring lalu lintas jaringan yang masuk.',10,false,false,'firewall',
    'Cek: sudo ufw status','Aktifkan: sudo ufw enable','["easy","medium","hard"]'),
  ('telnet_disabled','Nonaktifkan Layanan Telnet','Tidak boleh terdapat layanan yang listening pada port TCP 23 (Telnet), mengingat protokol ini mengirimkan kredensial dalam bentuk plaintext.',10,false,false,'service',
    'Cek layanan port 23 (telnet).','Matikan service simulasinya: sudo systemctl disable --now dhc-telnetd','["easy","medium","hard"]'),
  ('rogue_user_removed','Hapus Akun Pengguna Tidak Sah','Akun pengguna mencurigakan "hacker" harus dihapus sepenuhnya dari sistem.',10,false,false,'account',
    'Periksa daftar user di /etc/passwd.','Hapus: sudo deluser --remove-home hacker','["easy","medium","hard"]'),
  ('shadow_perm','Perbaiki Izin Akses Berkas /etc/shadow','Berkas /etc/shadow tidak boleh dapat dibaca oleh pengguna lain (world-readable); izin akses yang benar adalah mode 640 atau yang lebih ketat.',10,false,false,'permission',
    'Cek: ls -l /etc/shadow','Perbaiki: sudo chmod 640 /etc/shadow','["easy","medium","hard"]'),
  ('passwd_perm','Perbaiki Izin Akses Berkas /etc/passwd','Berkas /etc/passwd tidak boleh dapat ditulis oleh grup maupun pengguna lain; izin akses yang benar adalah mode 644.',10,false,false,'permission',
    'Cek: ls -l /etc/passwd','Perbaiki: sudo chmod 644 /etc/passwd','["easy","medium","hard"]'),
  ('empty_password_removed','Hapus Akun dengan Kata Sandi Kosong','Tidak boleh terdapat akun login dengan kata sandi kosong pada berkas /etc/shadow.',10,false,false,'account',
    'Cek /etc/shadow — akun dengan field password kosong berbahaya. Setelah memperbaiki, verifikasi field password-nya benar-benar TIDAK kosong lagi (mis. sudo grep <user> /etc/shadow) — sebagian cara mengunci akun tidak selalu mengubah field ini kalau password sebelumnya memang kosong.','Set field password langsung: sudo usermod -p ''!'' <user>  (paling pasti — passwd -l bisa tidak konsisten pada akun berpassword kosong). Alternatif: sudo deluser --remove-home <user>','["medium","hard"]'),
  ('uid0_unique','Pastikan Hanya Root yang Memiliki UID 0','Tidak boleh ada akun selain root yang memiliki User ID (UID) bernilai 0, karena hal tersebut setara dengan hak akses root.',10,false,false,'account',
    'Cek UID 0 di /etc/passwd — hanya root yang boleh. Perintah hapus akun standar bisa ditolak karena akun ini berbagi UID 0 dengan root (dianggap ''sedang dipakai'') — cek opsi paksa (force) pada man page perintahnya.','Hapus akun UID 0 palsu: sudo userdel -f <user>  (wajib -f — lihat catatan di kunci jawaban)','["medium","hard"]'),
  ('ip_forward_disabled','Nonaktifkan IP Forwarding','Parameter kernel net.ipv4.ip_forward harus bernilai 0, karena sistem peserta bukan merupakan router dan tidak boleh meneruskan paket antar-jaringan.',10,false,false,'network',
    'Cek: cat /proc/sys/net/ipv4/ip_forward','Matikan: sudo sysctl -w net.ipv4.ip_forward=0','["medium","hard"]'),
  ('password_max_days','Terapkan Batas Masa Berlaku Kata Sandi','Nilai PASS_MAX_DAYS pada /etc/login.defs harus 365 hari atau kurang, agar kata sandi wajib diperbarui secara berkala.',10,false,false,'policy',
    'Cek /etc/login.defs PASS_MAX_DAYS.','Set PASS_MAX_DAYS 365 (atau lebih kecil) di /etc/login.defs','["medium","hard"]'),
  ('ssh_permitempty_disabled','Larang Autentikasi SSH dengan Kata Sandi Kosong','Konfigurasi SSH tidak boleh mengizinkan login dengan kata sandi kosong; parameter PermitEmptyPasswords harus bernilai "no".',10,false,false,'ssh',
    'Cek /etc/ssh/sshd_config PermitEmptyPasswords.','Set "PermitEmptyPasswords no" lalu: sudo systemctl restart ssh','["medium","hard"]'),
  ('world_writable_removed','Amankan Berkas yang Dapat Ditulis oleh Semua Pengguna','Berkas /opt/dhc/secret.txt tidak boleh dapat ditulis oleh pengguna lain (world-writable).',10,false,false,'permission',
    'Cek: ls -l /opt/dhc/secret.txt','Perbaiki: sudo chmod 644 /opt/dhc/secret.txt','["hard"]'),
  ('suid_bash_removed','Hapus Shell Backdoor Berbit SUID','Salinan shell berbit SUID pada /usr/local/bin/rootbash merupakan backdoor yang memberikan hak akses root secara instan dan harus dihapus.',10,false,false,'privilege',
    'Cek: ls -l /usr/local/bin/rootbash','Hapus: sudo rm -f /usr/local/bin/rootbash','["hard"]'),
  ('rogue_sudo_removed','Cabut Hak Akses Sudo yang Tidak Sah','Akun "backdoor" tidak boleh menjadi anggota grup sudo.',10,false,false,'privilege',
    'Cek: getent group sudo','Cabut: sudo gpasswd -d backdoor sudo  (atau hapus akun: sudo deluser backdoor)','["hard"]'),
  ('cron_backdoor_removed','Hapus Cron Job Backdoor','Berkas terjadwal /etc/cron.d/dhc-backdoor merupakan mekanisme persistence yang tidak sah dan harus dihapus.',10,false,false,'persistence',
    'Periksa /etc/cron.d/ untuk job yang tidak dikenal.','Hapus: sudo rm -f /etc/cron.d/dhc-backdoor','["hard"]')
on conflict (code) do update set
  title=excluded.title, description=excluded.description, points=excluded.points,
  is_penalty=excluded.is_penalty, must_stay_passing=excluded.must_stay_passing,
  category=excluded.category, hint_basic=excluded.hint_basic,
  hint_advanced=excluded.hint_advanced, difficulty_tags=excluded.difficulty_tags;

-- ---------------- PRESET TINGKAT (subset berbeda) ----------------
insert into difficulties (key, name, description, active_check_codes, hint_policy, penalty_weight, default_duration_sec) values
  ('easy','Mudah','Lomba perdana/pemula. 6 soal dasar, hint lengkap, penalti ringan.',
    '["ssh_root_disabled","ufw_enabled","telnet_disabled","rogue_user_removed","shadow_perm","passwd_perm"]',
    'full', 0.5, 7200),
  ('medium','Medium','Peserta terbiasa. 11 soal, hint terbatas, penalti standar.',
    '["ssh_root_disabled","ufw_enabled","telnet_disabled","rogue_user_removed","shadow_perm","passwd_perm","empty_password_removed","uid0_unique","ip_forward_disabled","password_max_days","ssh_permitempty_disabled"]',
    'limited', 1.0, 5400),
  ('hard','Hard','Peserta mahir. 15 soal (termasuk backdoor tersembunyi), hint minim, penalti berat.',
    '["ssh_root_disabled","ufw_enabled","telnet_disabled","rogue_user_removed","shadow_perm","passwd_perm","empty_password_removed","uid0_unique","ip_forward_disabled","password_max_days","ssh_permitempty_disabled","world_writable_removed","suid_bash_removed","rogue_sudo_removed","cron_backdoor_removed"]',
    'none', 1.5, 3600)
on conflict (key) do update set
  name=excluded.name, description=excluded.description,
  active_check_codes=excluded.active_check_codes, hint_policy=excluded.hint_policy,
  penalty_weight=excluded.penalty_weight, default_duration_sec=excluded.default_duration_sec;
