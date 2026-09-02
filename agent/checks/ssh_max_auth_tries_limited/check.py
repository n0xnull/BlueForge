"""Check: SSH MaxAuthTries dibatasi.

PASS bila baris efektif MaxAuthTries di /etc/ssh/sshd_config <= 4.
"""
import os
import re

SSHD_CONFIG = "/etc/ssh/sshd_config"


def run(ctx=None):
    path = (ctx or {}).get("sshd_config", SSHD_CONFIG)
    if not os.path.isfile(path):
        return {"passed": False, "evidence": {"reason": "sshd_config tidak ditemukan"}}

    val = None
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                s = line.strip()
                if not s or s.startswith("#"):
                    continue
                m = re.match(r"(?i)^MaxAuthTries\s+(\d+)", s)
                if m:
                    val = int(m.group(1))
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}

    passed = val is not None and val <= 4
    return {"passed": passed, "evidence": {"max_auth_tries": val}}
