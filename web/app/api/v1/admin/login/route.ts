import { NextRequest, NextResponse } from "next/server";
import { ADMIN_COOKIE, adminToken, passwordValid, isAdmin } from "@/lib/auth";
import { supabaseAdmin } from "@/lib/supabase";

export const dynamic = "force-dynamic";

const RATE_WINDOW_MS = 10 * 60 * 1000; // 10 menit
const RATE_MAX_ATTEMPTS = 6;

function clientIp(req: NextRequest): string {
  const fwd = req.headers.get("x-forwarded-for");
  if (fwd) return fwd.split(",")[0].trim();
  return req.headers.get("x-real-ip") || "unknown";
}

// GET /api/v1/admin/login  -> cek status sesi (untuk auto-detect login di UI)
export async function GET(req: NextRequest) {
  return NextResponse.json({ authed: isAdmin(req) });
}

// POST /api/v1/admin/login  { password }  -> set cookie sesi
//
// Rate limit percobaan gagal (docs/REVIEW-AND-CONCEPT-v2.md §4.1/§4.4) --
// sebelumnya endpoint ini TIDAK PUNYA pembatasan sama sekali, jadi password
// admin bisa di-brute-force tanpa hambatan apa pun. Dibackend ke
// `event_logs` (bukan in-memory Map) supaya tetap efektif di lingkungan
// serverless (Vercel) yang instance prosesnya bisa berganti-ganti antar
// request -- in-memory counter akan reset diam-diam kalau begitu.
export async function POST(req: NextRequest) {
  const db = supabaseAdmin();
  const ip = clientIp(req);

  const since = new Date(Date.now() - RATE_WINDOW_MS).toISOString();
  const { data: recentFails } = await db
    .from("event_logs")
    .select("payload, created_at")
    .eq("type", "admin_login_failed")
    .gte("created_at", since)
    .order("created_at", { ascending: false })
    .limit(200);
  const failCount = (recentFails ?? []).filter((e: any) => e.payload?.ip === ip).length;
  if (failCount >= RATE_MAX_ATTEMPTS) {
    return NextResponse.json(
      { ok: false, error: "Terlalu banyak percobaan gagal. Coba lagi dalam beberapa menit." },
      { status: 429 }
    );
  }

  const body = await req.json().catch(() => ({}));
  if (!passwordValid(body.password || "")) {
    await db.from("event_logs").insert({
      type: "admin_login_failed", level: "SECURITY", payload: { ip },
    });
    return NextResponse.json({ ok: false, error: "Password salah" }, { status: 401 });
  }

  const res = NextResponse.json({ ok: true });
  res.cookies.set(ADMIN_COOKIE, adminToken(), {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production", // https di Vercel; http saat dev lokal
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 12, // 12 jam
  });
  return res;
}

// DELETE /api/v1/admin/login  -> logout
export async function DELETE() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set(ADMIN_COOKIE, "", { httpOnly: true, path: "/", maxAge: 0 });
  return res;
}
