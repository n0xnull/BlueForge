"""Check: net.ipv4.conf.all.accept_redirects == 0."""

PATH = "/proc/sys/net/ipv4/conf/all/accept_redirects"


def run(ctx=None):
    path = (ctx or {}).get("redirects_path", PATH)
    try:
        with open(path, "r") as f:
            val = f.read().strip()
        return {"passed": val == "0", "evidence": {"accept_redirects": val}}
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}
