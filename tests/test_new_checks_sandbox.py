"""Sandbox test — 15 check baru v0.4 (TDD §25 gaya sama dgn test_score_engine).

Karena tidak ada akses ke VM Ubuntu lomba yang sesungguhnya, test ini
memverifikasi LOGIKA tiap check.py terhadap fixture sintetis (file/dir
sementara) yang meniru kondisi "masih rentan" (harus FAIL) dan "sudah
diperbaiki" (harus PASS) -- lewat parameter `ctx` yang sudah didukung tiap
check.py (override path, bukan path asli /etc/... /proc/...).

Jalankan: cd tests && python3 test_new_checks_sandbox.py
"""
import importlib.util
import os
import stat
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CHECKS_DIR = os.path.join(HERE, "..", "agent", "checks")


def load_check(code):
    path = os.path.join(CHECKS_DIR, code, "check.py")
    spec = importlib.util.spec_from_file_location(f"check_{code}", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _write(path, content):
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def _proc_net_tcp(port_hex, listening=True):
    header = "  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode\n"
    if not listening:
        return header
    row = f"   0: 00000000:{port_hex} 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 12345 1 0000000000000000 100 0 0 10 0\n"
    return header + row


FAILED = []


def check(name, condition, detail=""):
    status = "PASS" if condition else "FAIL"
    print(f"{status} {name}" + (f" -- {detail}" if detail and not condition else ""))
    if not condition:
        FAILED.append(name)


def with_tmp(fn):
    with tempfile.TemporaryDirectory() as d:
        fn(d)


# ---------------------------------------------------------------------
def test_ftp_disabled():
    mod = load_check("ftp_disabled")
    with tempfile.TemporaryDirectory() as d:
        tcp = os.path.join(d, "tcp")
        tcp6 = os.path.join(d, "tcp6")
        _write(tcp, _proc_net_tcp("0015", listening=True))
        _write(tcp6, _proc_net_tcp("0015", listening=False))
        r = mod.run({"proc_tcp": tcp, "proc_tcp6": tcp6})
        check("ftp_disabled: vulnerable(listening) -> FAIL", r["passed"] is False)

        _write(tcp, _proc_net_tcp("0015", listening=False))
        r = mod.run({"proc_tcp": tcp, "proc_tcp6": tcp6})
        check("ftp_disabled: fixed(not listening) -> PASS", r["passed"] is True)


def test_backdoor_listener_removed():
    mod = load_check("backdoor_listener_removed")
    with tempfile.TemporaryDirectory() as d:
        tcp = os.path.join(d, "tcp")
        tcp6 = os.path.join(d, "tcp6")
        _write(tcp, _proc_net_tcp("115C", listening=True))
        _write(tcp6, _proc_net_tcp("115C", listening=False))
        r = mod.run({"proc_tcp": tcp, "proc_tcp6": tcp6})
        check("backdoor_listener_removed: vulnerable -> FAIL", r["passed"] is False)

        _write(tcp, _proc_net_tcp("115C", listening=False))
        r = mod.run({"proc_tcp": tcp, "proc_tcp6": tcp6})
        check("backdoor_listener_removed: fixed -> PASS", r["passed"] is True)


def test_ssh_x11_forwarding_disabled():
    mod = load_check("ssh_x11_forwarding_disabled")
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "sshd_config")
        _write(p, "Port 22\nX11Forwarding yes\n")
        r = mod.run({"sshd_config": p})
        check("ssh_x11: vulnerable(yes) -> FAIL", r["passed"] is False)

        _write(p, "Port 22\nX11Forwarding no\n")
        r = mod.run({"sshd_config": p})
        check("ssh_x11: fixed(no) -> PASS", r["passed"] is True)

        _write(p, "Port 22\n#X11Forwarding yes\n")
        r = mod.run({"sshd_config": p})
        check("ssh_x11: commented out (unset) -> FAIL (butuh eksplisit no)", r["passed"] is False)


def test_ssh_max_auth_tries_limited():
    mod = load_check("ssh_max_auth_tries_limited")
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "sshd_config")
        _write(p, "MaxAuthTries 10\n")
        r = mod.run({"sshd_config": p})
        check("ssh_max_auth_tries: vulnerable(10) -> FAIL", r["passed"] is False)

        _write(p, "MaxAuthTries 4\n")
        r = mod.run({"sshd_config": p})
        check("ssh_max_auth_tries: fixed(4) -> PASS", r["passed"] is True)

        _write(p, "MaxAuthTries 3\n")
        r = mod.run({"sshd_config": p})
        check("ssh_max_auth_tries: fixed(3) -> PASS", r["passed"] is True)


def test_tmp_sticky_bit_set():
    mod = load_check("tmp_sticky_bit_set")
    with tempfile.TemporaryDirectory() as d:
        target = os.path.join(d, "tmp")
        os.mkdir(target)
        os.chmod(target, 0o777)
        r = mod.run({"tmp_path": target})
        check("tmp_sticky_bit: vulnerable(0777 no sticky) -> FAIL", r["passed"] is False)

        os.chmod(target, 0o1777)
        r = mod.run({"tmp_path": target})
        check("tmp_sticky_bit: fixed(1777 sticky) -> PASS", r["passed"] is True)


def test_password_min_days_set():
    mod = load_check("password_min_days_set")
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "login.defs")
        _write(p, "PASS_MIN_DAYS\t0\n")
        r = mod.run({"login_defs": p})
        check("password_min_days: vulnerable(0) -> FAIL", r["passed"] is False)

        _write(p, "PASS_MIN_DAYS\t1\n")
        r = mod.run({"login_defs": p})
        check("password_min_days: fixed(1) -> PASS", r["passed"] is True)


def _sysctl_case(code, ctx_key, bad_val, good_val):
    mod = load_check(code)
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "val")
        _write(p, bad_val + "\n")
        r = mod.run({ctx_key: p})
        check(f"{code}: vulnerable({bad_val}) -> FAIL", r["passed"] is False)

        _write(p, good_val + "\n")
        r = mod.run({ctx_key: p})
        check(f"{code}: fixed({good_val}) -> PASS", r["passed"] is True)


def test_sysctl_checks():
    _sysctl_case("syn_cookies_enabled", "syncookies_path", "0", "1")
    _sysctl_case("aslr_enabled", "aslr_path", "0", "2")
    _sysctl_case("icmp_redirects_disabled", "redirects_path", "1", "0")
    _sysctl_case("source_routing_disabled", "source_route_path", "1", "0")
    _sysctl_case("core_dump_restricted", "suid_dumpable_path", "2", "0")


def test_unsafe_path_removed():
    mod = load_check("unsafe_path_removed")
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "99-dhc-path.sh")
        _write(p, '# comment\nexport PATH=".:$PATH"\n')
        r = mod.run({"dhc_path_file": p})
        check("unsafe_path: vulnerable(.:$PATH) -> FAIL", r["passed"] is False)

        _write(p, '# export PATH=".:$PATH"  -- dikomentari peserta\n')
        r = mod.run({"dhc_path_file": p})
        check("unsafe_path: baris dikomentari -> PASS", r["passed"] is True)

        # file dihapus total
        r = mod.run({"dhc_path_file": os.path.join(d, "tidak-ada.sh")})
        check("unsafe_path: file dihapus -> PASS", r["passed"] is True)


def test_rogue_crontab_removed():
    mod = load_check("rogue_crontab_removed")
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "svc-backup")
        _write(p, "* * * * * curl -s http://169.254.169.254/ >> /tmp/.cache\n")
        r = mod.run({"crontab_path": p})
        check("rogue_crontab: vulnerable(ada baris aktif) -> FAIL", r["passed"] is False)

        _write(p, "# DO NOT EDIT\n")
        r = mod.run({"crontab_path": p})
        check("rogue_crontab: cuma komentar -> PASS", r["passed"] is True)

        r = mod.run({"crontab_path": os.path.join(d, "tidak-ada")})
        check("rogue_crontab: file tidak ada -> PASS", r["passed"] is True)


def test_cron_writable_script_removed():
    mod = load_check("cron_writable_script_removed")
    with tempfile.TemporaryDirectory() as d:
        script = os.path.join(d, "backup.sh")
        cron = os.path.join(d, "dhc-backup")
        _write(script, "#!/bin/bash\n/bin/true\n")
        os.chmod(script, 0o777)
        _write(cron, "* * * * * root /opt/dhc/backup.sh\n")
        r = mod.run({"script_path": script, "cron_path": cron})
        check("cron_writable_script: vulnerable(0777 + cron ada) -> FAIL", r["passed"] is False)

        os.chmod(script, 0o750)
        r = mod.run({"script_path": script, "cron_path": cron})
        check("cron_writable_script: script dibetulkan(0750) -> PASS", r["passed"] is True)

        os.chmod(script, 0o777)
        r = mod.run({"script_path": script, "cron_path": os.path.join(d, "tidak-ada")})
        check("cron_writable_script: cron dihapus (meski script msh 777) -> PASS", r["passed"] is True)


def test_duplicate_uid_removed():
    mod = load_check("duplicate_uid_removed")
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "passwd")
        _write(p, "root:x:0:0:root:/root:/bin/bash\ndhcspy1:x:1500:1500::/nonexistent:/usr/sbin/nologin\ndhcspy2:x:1500:1500::/nonexistent:/usr/sbin/nologin\n")
        r = mod.run({"passwd_path": p})
        check("duplicate_uid: vulnerable(uid kembar 1500) -> FAIL", r["passed"] is False)

        _write(p, "root:x:0:0:root:/root:/bin/bash\ndhcspy2:x:1501:1501::/nonexistent:/usr/sbin/nologin\n")
        r = mod.run({"passwd_path": p})
        check("duplicate_uid: fixed(salah satu dihapus) -> PASS", r["passed"] is True)


if __name__ == "__main__":
    test_ftp_disabled()
    test_backdoor_listener_removed()
    test_ssh_x11_forwarding_disabled()
    test_ssh_max_auth_tries_limited()
    test_tmp_sticky_bit_set()
    test_password_min_days_set()
    test_sysctl_checks()
    test_unsafe_path_removed()
    test_rogue_crontab_removed()
    test_cron_writable_script_removed()
    test_duplicate_uid_removed()

    print()
    if FAILED:
        print(f"FAILED: {len(FAILED)} -> {FAILED}")
        sys.exit(1)
    else:
        print("ALL SANDBOX CHECKS PASSED")
