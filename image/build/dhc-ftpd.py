#!/usr/bin/env python3
"""abilithic DHC — simulasi service FTP (SENGAJA rentan, soal `ftp_disabled`).

Sama seperti dhc-telnetd.py: paket FTP server sungguhan (vsftpd/proftpd) tidak
selalu terpasang/menyala konsisten di semua varian image Ubuntu, sehingga
soal ini bisa "PASS sendiri" tanpa peserta berbuat apa-apa kalau kita
bergantung pada paket asli. Listener minimal ini SELALU bisa jalan di Ubuntu
versi berapa pun karena cuma pakai modul `socket` bawaan Python.

BUKAN implementasi protokol FTP sungguhan — cukup socket yang menerima
koneksi & mengirim banner login palsu, karena
`agent/checks/ftp_disabled/check.py` HANYA menguji status LISTEN di port
TCP 21, bukan menguji kebenaran protokolnya.

Peserta WAJIB mematikan lewat systemd (bukan cuma bunuh proses):
    sudo systemctl disable --now dhc-ftpd
"""
import socket

HOST, PORT = "0.0.0.0", 21
BANNER = b"220 (vsFTPd 3.0.5)\r\n"


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((HOST, PORT))
    srv.listen(20)
    while True:
        conn, _addr = srv.accept()
        try:
            conn.sendall(BANNER)
        except Exception:
            pass
        finally:
            conn.close()


if __name__ == "__main__":
    main()
