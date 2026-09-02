"""Check: fs.suid_dumpable == 0."""

PATH = "/proc/sys/fs/suid_dumpable"


def run(ctx=None):
    path = (ctx or {}).get("suid_dumpable_path", PATH)
    try:
        with open(path, "r") as f:
            val = f.read().strip()
        return {"passed": val == "0", "evidence": {"suid_dumpable": val}}
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}
