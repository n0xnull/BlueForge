"""Check: listener backdoor (simulasi) di port 4444 sudah dimatikan.

PASS bila tidak ada socket LISTEN di port 4444 (TCP). Port 4444 = 0x115C.
"""

LISTEN = "0A"
PORT_4444_HEX = "115C"


def _has_listen_on(path, port_hex):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            next(f, None)
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
    listening = _has_listen_on(tcp_path, PORT_4444_HEX) or _has_listen_on(tcp6_path, PORT_4444_HEX)
    return {
        "passed": not listening,
        "evidence": {"backdoor_port_4444_listening": listening},
    }
