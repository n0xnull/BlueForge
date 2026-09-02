"""Check: SSH X11 forwarding dinonaktifkan.

PASS bila /etc/ssh/sshd_config memiliki 'X11Forwarding no' (efektif,
mengabaikan baris komentar).
"""
import os
import re

SSHD_CONFIG = "/etc/ssh/sshd_config"


def run(ctx=None):
    path = (ctx or {}).get("sshd_config", SSHD_CONFIG)
    if not os.path.isfile(path):
        return {"passed": False, "evidence": {"reason": "sshd_config tidak ditemukan"}}

    effective = None
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                s = line.strip()
                if not s or s.startswith("#"):
                    continue
                m = re.match(r"(?i)^X11Forwarding\s+(\S+)", s)
                if m:
                    effective = m.group(1).lower()
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}

    passed = (effective == "no")
    return {
        "passed": passed,
        "evidence": {"x11_forwarding": effective if effective is not None else "default(unset)"},
    }
