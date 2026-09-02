"""Check: Izin akses /root aman. PASS bila others tidak punya izin akses (read/write/exec) dan group tidak punya write permission."""
import os

def run(ctx=None):
    path = (ctx or {}).get("root_path", "/root")
    try:
        st = os.stat(path)
        mode = st.st_mode
        others_perm = mode & 0o007
        group_write = mode & 0o020
        passed = (others_perm == 0) and (group_write == 0)
        mode_oct = oct(mode & 0o777)
        return {"passed": passed, "evidence": {"path": path, "mode": mode_oct}}
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}
