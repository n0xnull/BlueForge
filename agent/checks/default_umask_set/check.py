"""Check: Nilai UMASK default sistem di /etc/login.defs aman (misal 022, 027, 077).

PASS bila UMASK <= 027 dan bukan 000.
"""
import os
import re

LOGIN_DEFS = "/etc/login.defs"

def run(ctx=None):
    path = (ctx or {}).get("login_defs_path", LOGIN_DEFS)
    try:
        if not os.path.exists(path):
            return {"passed": False, "evidence": {"error": f"{path} tidak ditemukan"}}
        
        effective_umask = None
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                s = line.strip()
                if not s or s.startswith("#"):
                    continue
                m = re.match(r"(?i)^UMASK\s+([0-7]+)", s)
                if m:
                    effective_umask = m.group(1)
        
        if effective_umask is None:
            return {"passed": False, "evidence": {"umask": None, "reason": "UMASK tidak ditemukan"}}
        
        val_oct = int(effective_umask, 8)
        # PASS bila umask <= 027 (octal 0o027 = 23) dan bukan 000 (0)
        passed = (val_oct <= 0o027) and (val_oct != 0)
        return {
            "passed": passed,
            "evidence": {"umask": effective_umask, "umask_oct": oct(val_oct)}
        }
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}
