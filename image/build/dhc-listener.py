#!/usr/bin/env python3
"""abilithic DHC — simulasi listener backdoor/reverse-shell (SENGAJA rentan,
soal `backdoor_listener_removed`), listen di port TCP 4444 — port yang
lazim dipakai payload reverse shell (mis. default msfvenom).

Sama seperti dhc-telnetd.py/dhc-ftpd.py: listener minimal ini cuma pakai
modul `socket` bawaan Python (tidak ada dependensi/paket eksternal), supaya
selalu bisa jalan konsisten di image mana pun dan soal ini tidak pernah
"PASS sendiri" secara tidak sengaja.

BUKAN backdoor sungguhan — tidak menjalankan shell apa pun ke koneksi yang
masuk, cuma menerima & menutup koneksi. `check.py` HANYA menguji status
LISTEN di port TCP 4444.

Peserta WAJIB mematikan lewat systemd (bukan cuma bunuh proses):
    sudo systemctl disable --now dhc-listener
"""
import socket

HOST, PORT = "0.0.0.0", 4444


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((HOST, PORT))
    srv.listen(20)
    while True:
        conn, _addr = srv.accept()
        try:
            conn.close()
        except Exception:
            pass


if __name__ == "__main__":
    main()
