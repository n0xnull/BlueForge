import crypto from "crypto";
import { NextRequest } from "next/server";

const MASTER = process.env.AGENT_HMAC_SECRET || "dev-master-secret";
const TS_WINDOW_MS = 5 * 60 * 1000; // toleransi 5 menit (TDD §11.3)

/** Turunkan agent_secret per peserta dari master + participant_id.
 *  Server bisa menghitung ulang tanpa menyimpan secret per baris. */
export function deriveSecret(participantId: string): string {
  return crypto.createHmac("sha256", MASTER).update(participantId).digest("hex");
}

export function sha256(s: string): string {
  return crypto.createHash("sha256").update(s).digest("hex");
}

function signCanonical(secret: string, method: string, path: string, body: string,
                       ts: string, nonce: string): string {
  const msg = `${method.toUpperCase()}\n${path}\n${body}\n${ts}\n${nonce}`;
  return crypto.createHmac("sha256", secret).update(msg).digest("hex");
}

/** Verifikasi request agen ber-signing.
 *
 *  `db` opsional: kalau diberikan, sekalian tegakkan anti-replay (TDD §37 --
 *  tabel `nonces` sudah ada di schema sejak v0.1 tapi sebelumnya TIDAK
 *  PERNAH benar-benar dicek di sini, jadi request ber-signing valid bisa
 *  di-replay bebas dalam jendela toleransi 5 menit). Caller cukup lewatkan
 *  `supabaseAdmin()` yang sudah dibuatnya sendiri -- lihat pemanggilan di
 *  masing-masing route (state/score/snapshot/heartbeat).
 *
 *  Return { ok, participantId } atau { ok:false, reason }. */
export async function verifyAgentRequest(
  req: NextRequest, path: string, rawBody: string, db?: { from: (table: string) => any }
): Promise<{ ok: true; participantId: string } | { ok: false; reason: string }> {
  const participantId = req.headers.get("x-participant") || "";
  const ts = req.headers.get("x-timestamp") || "";
  const nonce = req.headers.get("x-nonce") || "";
  const sig = req.headers.get("x-signature") || "";

  if (!participantId || !ts || !nonce || !sig) {
    return { ok: false, reason: "missing auth headers" };
  }
  const tsNum = Number(ts);
  if (!Number.isFinite(tsNum) || Math.abs(Date.now() - tsNum) > TS_WINDOW_MS) {
    return { ok: false, reason: "timestamp out of window" };
  }
  const secret = deriveSecret(participantId);
  const expected = signCanonical(secret, req.method, path, rawBody, ts, nonce);
  // perbandingan konstan-waktu
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    return { ok: false, reason: "bad signature" };
  }

  if (db) {
    // (participant_id, nonce) adalah primary key -- insert gagal dgn unique
    // violation berarti nonce ini SUDAH PERNAH dipakai peserta yang sama =
    // request sedang di-replay, tolak. Kegagalan lain (mis. tabel belum
    // ke-migrate / DB sedang bermasalah) sengaja TIDAK memblokir seluruh
    // sesi lomba -- fail-open utk lapisan pertahanan opsional ini, hanya
    // di-log. Blokir keras hanya utk replay yang benar-benar terdeteksi.
    try {
      const { error } = await db.from("nonces").insert({ participant_id: participantId, nonce });
      if (error) {
        const code = (error as any).code;
        const msg = String((error as any).message || "");
        if (code === "23505" || /duplicate/i.test(msg)) {
          return { ok: false, reason: "replay detected" };
        }
        console.warn("nonce_check_failed", msg);
      }
    } catch (e: any) {
      console.warn("nonce_check_exception", e?.message);
    }
  }

  return { ok: true, participantId };
}
