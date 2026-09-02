"""Check Runner (TDD §15, §35).

Memuat semua check (plugin-style) dari agent/checks/<code>/ (manifest.yaml + check.py),
menjalankan yang AKTIF sesuai daftar dari server, mengumpulkan hasil + evidence.

Engine tidak tahu detail tiap check — hanya kontrak: run(ctx) -> {"passed": bool, "evidence": {...}}
"""
import importlib.util
import os
import yaml


class LoadedCheck:
    def __init__(self, manifest: dict, run_fn):
        self.code = manifest["code"]
        self.manifest = manifest
        self._run = run_fn

    @property
    def points(self):
        return int(self.manifest.get("points", 10))

    @property
    def is_penalty(self):
        return bool(self.manifest.get("is_penalty", False))

    @property
    def must_stay_passing(self):
        return bool(self.manifest.get("must_stay_passing", False))

    def hint(self, policy: str):
        """Hint HANYA berupa arahan (guiding) dari `hint_basic` -- TIDAK
        PERNAH mengembalikan command jawaban langsung.

        Sejak v0.4, field `hint_advanced` (command siap pakai) sengaja tidak
        lagi dipakai sama sekali (lihat docs/REVIEW-AND-CONCEPT-v2.md /
        CHANGELOG) -- panitia FITCOM minta hint hanya mengarahkan, bukan
        memberi jawaban langsung. Hanya sebagian kecil soal (~25%, lihat
        db/seed/difficulties.sql) yang punya `hint_basic` sama sekali;
        sisanya otomatis None di sini (tidak ada hint ditampilkan).
        """
        if policy == "none":
            return None
        return self.manifest.get("hint_basic")

    def run(self, ctx=None):
        try:
            result = self._run(ctx or {})
            if not isinstance(result, dict) or "passed" not in result:
                return {"passed": False, "evidence": {"error": "invalid check return"}}
            result.setdefault("evidence", {})
            return result
        except Exception as e:  # check tak boleh menjatuhkan agen
            return {"passed": False, "evidence": {"error": str(e)}}


class CheckRunner:
    def __init__(self, logger, checks_dir=None):
        self.log = logger
        self.checks_dir = checks_dir or os.path.join(os.path.dirname(__file__), "..", "checks")
        self.checks = {}  # code -> LoadedCheck
        self._load_all()

    def _load_all(self):
        base = os.path.abspath(self.checks_dir)
        if not os.path.isdir(base):
            self.log.error("checks_dir_missing", path=base)
            return
        for entry in sorted(os.listdir(base)):
            cdir = os.path.join(base, entry)
            manifest_path = os.path.join(cdir, "manifest.yaml")
            check_path = os.path.join(cdir, "check.py")
            if not (os.path.isfile(manifest_path) and os.path.isfile(check_path)):
                continue
            try:
                with open(manifest_path, "r", encoding="utf-8") as f:
                    manifest = yaml.safe_load(f)
                spec = importlib.util.spec_from_file_location(f"check_{entry}", check_path)
                mod = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(mod)
                run_fn = getattr(mod, "run")
                self.checks[manifest["code"]] = LoadedCheck(manifest, run_fn)
                self.log.debug("check_loaded", code=manifest["code"])
            except Exception as e:
                self.log.error("check_load_failed", entry=entry, error=str(e))

    def active_checks_meta(self, active_codes):
        """Metadata (utk scoring engine) untuk check yang aktif."""
        meta = []
        for code in active_codes:
            c = self.checks.get(code)
            if c:
                meta.append({
                    "code": c.code,
                    "points": c.points,
                    "is_penalty": c.is_penalty,
                    "must_stay_passing": c.must_stay_passing,
                })
        return meta

    def run_active(self, active_codes, ctx=None):
        """Jalankan check aktif. Return (state_dict, evidence_dict).
        state_dict: code -> passed(bool); evidence_dict: code -> evidence.
        """
        state, evidence = {}, {}
        for code in active_codes:
            c = self.checks.get(code)
            if not c:
                self.log.warn("active_check_not_found", code=code)
                continue
            res = c.run(ctx)
            state[code] = bool(res.get("passed"))
            evidence[code] = res.get("evidence", {})
        return state, evidence

    def hints(self, active_codes, policy):
        out = {}
        for code in active_codes:
            c = self.checks.get(code)
            if c:
                out[code] = {"title": c.manifest.get("title"), "hint": c.hint(policy)}
        return out
