"""Network Client (TDD §16, §17).

Tanggung jawab:
- Panggil endpoint /v1 (register, state, score, snapshot, heartbeat).
- Sertakan header signing HMAC untuk endpoint agen.
- Retry + exponential backoff + jitter pada kegagalan jaringan/5xx.
- Store-and-forward: skor/snapshot saat OFFLINE diantre & dikirim ulang (idempoten).
"""
import json
import random
import time

import requests

from crypto import build_auth_headers

BACKOFF_SCHEDULE = [5, 10, 20, 40, 60]  # detik (TDD §17.2)


class ApiClient:
    def __init__(self, base_url, logger, timeout=15):
        self.base = base_url.rstrip("/")
        self.log = logger
        self.timeout = timeout
        self.participant_id = None
        self.secret = None
        self._queue = []  # store-and-forward: list of (path, payload)
        # Sinyal spesifik utk main.py: True HANYA saat server sudah TEGAS
        # bilang "participant tidak dikenal" (baris peserta hilang dari DB --
        # mis. dihapus panitia lewat admin, atau DB direset). Dipisah dari
        # error 401 lain (timestamp skew, replay, signature) yang SIFATNYA
        # SEMENTARA dan TIDAK BOLEH memicu penghapusan sesi lokal -- kalau
        # semua 401 dianggap sama, satu hiccup jaringan bisa bikin agen
        # "lupa" peserta yang sebenarnya masih valid, padahal registrasi
        # ulang akan DITOLAK server (unique constraint), jadi peserta
        # terkunci total dari sesi lomba. Lihat Runtime.sync_once().
        self.participant_not_found = False
        # Koreksi jam lokal VM vs jam server (TDD/ADR clock-skew, lihat sync_clock()).
        # Tanpa ini, VM dengan jam salah (umum pada clone/template VMware tanpa
        # NTP) akan gagal jendela toleransi timestamp server (±5 menit) dan
        # seluruh sinkronisasi tampak "macet" sampai jam VM dikoreksi manual.
        self.clock_offset_ms = 0

    def set_credentials(self, participant_id, secret):
        self.participant_id = participant_id
        self.secret = secret

    # ---------- low-level ----------
    def _post(self, path, payload, signed=True):
        url = self.base + path
        body = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
        headers = {"Content-Type": "application/json"}
        if signed and self.participant_id and self.secret:
            headers = build_auth_headers(self.participant_id, self.secret, "POST", path, body,
                                         clock_offset_ms=self.clock_offset_ms)
        resp = requests.post(url, data=body.encode("utf-8"), headers=headers, timeout=self.timeout)
        return resp

    def _get(self, path, signed=True, query=None):
        # query (mis. ?t=123) ditambahkan ke URL utk cache-bust, TAPI tanda tangan
        # tetap atas `path` polos (server verifikasi path tanpa query).
        url = self.base + path + (query or "")
        headers = {"Cache-Control": "no-cache", "Pragma": "no-cache"}
        if signed and self.participant_id and self.secret:
            headers.update(build_auth_headers(self.participant_id, self.secret, "GET", path, "",
                                              clock_offset_ms=self.clock_offset_ms))
        resp = requests.get(url, headers=headers, timeout=self.timeout)
        return resp

    # ---------- clock sync (anti clock-skew VMware/Ubuntu) ----------
    def sync_clock(self):
        """Tanya jam server (endpoint publik, tanpa signing) lalu simpan offset.
        Dipanggil tiap siklus poll SEBELUM request ber-signing lain — memutus
        masalah ayam-telur (butuh request untuk tahu skew, tapi request
        ber-signing butuh jam yang sudah benar). Gagal = diam-diam pertahankan
        offset lama (lebih baik daripada 0 tiba-tiba bila server sedang lambat)."""
        try:
            t0 = time.time() * 1000
            resp = requests.get(self.base + "/api/v1/time", timeout=self.timeout)
            t1 = time.time() * 1000
            if resp.status_code == 200:
                server_ms = resp.json().get("server_time_ms")
                if server_ms is not None:
                    # kompensasi separuh round-trip network agar lebih presisi
                    local_mid = (t0 + t1) / 2
                    self.clock_offset_ms = int(server_ms - local_mid)
                    return True
        except requests.RequestException as e:
            self.log.warn("clock_sync_error", error=str(e))
        return False

    # ---------- endpoints ----------
    def register(self, name, school, session_code, image_version):
        payload = {"name": name, "school": school,
                   "session_code": session_code, "image_version": image_version}
        resp = self._post("/api/v1/register", payload, signed=False)
        if resp.status_code == 200:
            return resp.json()
        raise RuntimeError(f"register gagal: {resp.status_code} {resp.text[:200]}")

    def get_state(self):
        """Return dict state atau None bila gagal (caller anggap OFFLINE).

        Selain None/dict, method ini SEKALIGUS men-set
        `self.participant_not_found` saat server eksplisit bilang baris
        peserta ini sudah tidak ada -- lihat komentar di __init__."""
        self.participant_not_found = False
        try:
            resp = self._get("/api/v1/state", query=f"?t={int(time.time() * 1000)}")
            if resp.status_code == 200:
                try:
                    return resp.json()
                except ValueError as e:
                    # respons 200 tapi body bukan JSON valid (mis. halaman
                    # error HTML dari proxy/CDN) -- jangan sampai exception
                    # ini menjatuhkan seluruh loop utama, anggap saja OFFLINE
                    # utk siklus ini dan coba lagi siklus berikutnya.
                    self.log.warn("state_bad_json", error=str(e))
                    return None
            if resp.status_code == 401:
                try:
                    body = resp.json()
                except ValueError:
                    body = {}
                if "tidak dikenal" in str(body.get("error", "")):
                    self.participant_not_found = True
            self.log.warn("state_non200", code=resp.status_code)
        except requests.RequestException as e:
            self.log.warn("state_network_error", error=str(e))
        return None

    def send_heartbeat(self, agent_version, uptime_s):
        try:
            self._post("/api/v1/heartbeat",
                       {"agent_version": agent_version, "uptime_s": uptime_s})
        except requests.RequestException:
            pass

    def send_score(self, total_score, checks, computed_at_ms):
        payload = {"total_score": total_score, "checks": checks,
                   "computed_at_ms": computed_at_ms}
        return self._enqueue_and_flush("/api/v1/score", payload)

    def send_snapshot(self, snapshot):
        return self._enqueue_and_flush("/api/v1/snapshot", snapshot)

    # ---------- store-and-forward ----------
    def _enqueue_and_flush(self, path, payload):
        self._queue.append((path, payload))
        return self.flush_queue()

    def flush_queue(self):
        """Kirim semua item antrian. Yang gagal tetap di antrian (retry nanti)."""
        remaining = []
        ok = True
        for path, payload in self._queue:
            try:
                resp = self._post(path, payload)
                if resp.status_code in (200, 409):
                    # 409 = sesi ended/duplikat: anggap selesai (idempoten), buang
                    continue
                if resp.status_code == 429:
                    self.log.warn("rate_limited", path=path)
                    remaining.append((path, payload))
                    ok = False
                elif 500 <= resp.status_code < 600:
                    remaining.append((path, payload))
                    ok = False
                else:
                    # 4xx lain: payload bermasalah, jangan ulang membabi buta
                    self.log.error("post_4xx", path=path, code=resp.status_code)
            except requests.RequestException as e:
                self.log.warn("post_network_error", path=path, error=str(e))
                remaining.append((path, payload))
                ok = False
        self._queue = remaining
        return ok

    def backoff_sleep(self, attempt):
        base = BACKOFF_SCHEDULE[min(attempt, len(BACKOFF_SCHEDULE) - 1)]
        jitter = base * 0.2 * (random.random() * 2 - 1)  # ±20%
        time.sleep(max(1, base + jitter))
