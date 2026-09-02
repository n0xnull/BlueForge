"""Check: net.ipv4.tcp_syncookies == 1."""

PATH = "/proc/sys/net/ipv4/tcp_syncookies"


def run(ctx=None):
    path = (ctx or {}).get("syncookies_path", PATH)
    try:
        with open(path, "r") as f:
            val = f.read().strip()
        return {"passed": val == "1", "evidence": {"tcp_syncookies": val}}
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}
