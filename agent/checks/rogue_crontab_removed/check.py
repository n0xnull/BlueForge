"""Check: crontab milik user rogue 'svc-backup' sudah dihapus/kosong.

PASS bila file crontab per-user untuk 'svc-backup' tidak ada, atau ada tapi
tidak punya baris aktif (bukan komentar).
"""
import os

DEFAULT_USER = "svc-backup"


def run(ctx=None):
    ctx = ctx or {}
    user = ctx.get("rogue_cron_user", DEFAULT_USER)
    path = ctx.get("crontab_path", f"/var/spool/cron/crontabs/{user}")
    if not os.path.exists(path):
        return {"passed": True, "evidence": {"note": "tidak ada crontab"}}
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
        active_lines = [l for l in content.splitlines() if l.strip() and not l.strip().startswith("#")]
        return {"passed": len(active_lines) == 0, "evidence": {"active_lines": len(active_lines)}}
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}
