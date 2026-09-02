"""Check: PATH sistem tidak menyertakan direktori tidak aman ('.').

PASS bila /etc/profile.d/99-dhc-path.sh tidak ada, atau ada tapi baris
AKTIF-nya (bukan komentar) sudah tidak menyisipkan '.' (current directory)
ke variabel PATH.
"""
import os

DEFAULT_PATH_FILE = "/etc/profile.d/99-dhc-path.sh"


def run(ctx=None):
    path = (ctx or {}).get("dhc_path_file", DEFAULT_PATH_FILE)
    if not os.path.exists(path):
        return {"passed": True, "evidence": {"note": "berkas tidak ada"}}
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}

    active = "\n".join(l for l in lines if l.strip() and not l.strip().startswith("#"))
    unsafe = (".:" in active) or (":." in active) or ('="."' in active.replace(" ", ""))
    return {
        "passed": not unsafe,
        "evidence": {"file_exists": True, "active_unsafe_entry": unsafe},
    }
