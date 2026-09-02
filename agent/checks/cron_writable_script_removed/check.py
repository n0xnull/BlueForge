"""Check: script yang dijalankan cron (sebagai root) tidak lagi world-writable.

PASS bila /opt/dhc/backup.sh tidak ada, ATAU ada tapi sudah tidak writable
oleh 'other'. Menghapus /etc/cron.d/dhc-backup (mekanisme cron-nya) juga
otomatis PASS karena script itu sudah tidak lagi dijalankan sebagai root.
"""
import os
import stat

SCRIPT = "/opt/dhc/backup.sh"
CRON = "/etc/cron.d/dhc-backup"


def run(ctx=None):
    ctx = ctx or {}
    script = ctx.get("script_path", SCRIPT)
    cron = ctx.get("cron_path", CRON)
    cron_removed = not os.path.exists(cron)
    if not os.path.exists(script):
        return {"passed": True, "evidence": {"note": "script tidak ada", "cron_removed": cron_removed}}
    try:
        perm = stat.S_IMODE(os.stat(script).st_mode)
        other_writable = bool(perm & 0o002)
        passed = cron_removed or (not other_writable)
        return {
            "passed": passed,
            "evidence": {"mode": oct(perm), "other_writable": other_writable, "cron_removed": cron_removed},
        }
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}
