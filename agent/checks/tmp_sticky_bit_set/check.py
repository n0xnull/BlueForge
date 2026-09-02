"""Check: sticky bit /tmp aktif.

PASS bila /tmp memiliki sticky bit (mode & 01000).
"""
import os
import stat

TMP_DIR = "/tmp"


def run(ctx=None):
    path = (ctx or {}).get("tmp_path", TMP_DIR)
    try:
        mode = os.stat(path).st_mode
        has_sticky = bool(mode & stat.S_ISVTX)
        return {
            "passed": has_sticky,
            "evidence": {"mode": oct(stat.S_IMODE(mode)), "sticky_bit": has_sticky},
        }
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}
