"""Check: tidak ada dua akun (selain root) yang berbagi UID yang sama.

PASS bila setiap UID di /etc/passwd (selain UID 0 -- dicek terpisah oleh
soal uid0_unique) hanya dipakai oleh SATU akun.
"""
import os
from collections import Counter


def run(ctx=None):
    path = (ctx or {}).get("passwd_path", "/etc/passwd")
    if not os.path.isfile(path):
        return {"passed": False, "evidence": {"reason": "passwd tidak ditemukan"}}
    try:
        uids = []
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                p = line.strip().split(":")
                if len(p) >= 3 and p[2].isdigit() and p[2] != "0":
                    uids.append(p[2])
    except Exception as e:
        return {"passed": False, "evidence": {"error": str(e)}}
    counts = Counter(uids)
    dupes = {uid: c for uid, c in counts.items() if c > 1}
    return {"passed": len(dupes) == 0, "evidence": {"duplicate_uids": dupes}}
