"""Check: PASS_MIN_DAYS >= 1 di /etc/login.defs."""
import re

LOGIN_DEFS = "/etc/login.defs"


def run(ctx=None):
    path = (ctx or {}).get("login_defs", LOGIN_DEFS)
    try:
        val = None
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                s = line.strip()
                if s.startswith("#"):
                    continue
                m = re.match(r"PASS_MIN_DAYS\s+(\d+)", s)
                if m:
                    val = int(m.group(1))
        passed = val is not None and val >= 1
        return {"passed": passed, "evidence": {"pass_min_days": val}}
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}
