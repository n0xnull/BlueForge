"""Check: net.ipv4.conf.all.accept_source_route == 0."""

PATH = "/proc/sys/net/ipv4/conf/all/accept_source_route"


def run(ctx=None):
    path = (ctx or {}).get("source_route_path", PATH)
    try:
        with open(path, "r") as f:
            val = f.read().strip()
        return {"passed": val == "0", "evidence": {"accept_source_route": val}}
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}
