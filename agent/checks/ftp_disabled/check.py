"""Check: FTP (simulasi) dimatikan.

PASS bila tidak ada socket LISTEN di port 21 (TCP). Sama persis pola dengan
telnet_disabled -- baca /proc/net/tcp[6] tanpa dependensi eksternal.
Port 21 = 0x0015 dalam hex.
"""

LISTEN = "0A"  # status TCP_LISTEN di /proc/net/tcp
PORT_21_HEX = "0015"


def _has_listen_on(path, port_hex):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            next(f, None)  # header
            for line in f:
                parts = line.split()
                if len(parts) < 4:
                    continue
                local = parts[1]
                st = parts[3]
                if st == LISTEN and local.upper().endswith(":" + port_hex):
                    return True
    except FileNotFoundError:
        return False
    except Exception:
        return False
    return False


def run(ctx=None):
    ctx = ctx or {}
    tcp_path = ctx.get("proc_tcp", "/proc/net/tcp")
    tcp6_path = ctx.get("proc_tcp6", "/proc/net/tcp6")
    listening = _has_listen_on(tcp_path, PORT_21_HEX) or _has_listen_on(tcp6_path, PORT_21_HEX)
    return {
        "passed": not listening,
        "evidence": {"ftp_port_21_listening": listening},
    }
