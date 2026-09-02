"""Check: kernel.randomize_va_space == 2 (ASLR penuh)."""

PATH = "/proc/sys/kernel/randomize_va_space"


def run(ctx=None):
    path = (ctx or {}).get("aslr_path", PATH)
    try:
        with open(path, "r") as f:
            val = f.read().strip()
        return {"passed": val == "2", "evidence": {"randomize_va_space": val}}
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}
