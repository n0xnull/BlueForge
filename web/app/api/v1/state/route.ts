import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";
import { verifyAgentRequest } from "@/lib/hmac";

export const dynamic = "force-dynamic";
export const revalidate = 0;
export const fetchCache = "force-no-store";

const NO_CACHE = {
  "Cache-Control": "no-store, no-cache, must-revalidate, max-age=0",
  "CDN-Cache-Control": "no-store",
  "Vercel-CDN-Cache-Control": "no-store",
};

// GET /api/v1/state  (TDD §16.2) — polling inti
export async function GET(req: NextRequest) {
  const db = supabaseAdmin();
  const auth = await verifyAgentRequest(req, "/api/v1/state", "", db);
  if (!auth.ok) {
    return NextResponse.json({ error: auth.reason }, { status: 401, headers: NO_CACHE });
  }
  const { data: participant } = await db
    .from("participants")
    .select("id,competition_id,status")
    .eq("id", auth.participantId)
    .maybeSingle();
  if (!participant) {
    return NextResponse.json({ error: "participant tidak dikenal" }, { status: 401, headers: NO_CACHE });
  }

  const { data: comp } = await db
    .from("competitions")
    .select("status,difficulty,hint_policy,penalty_weight,ends_at")
    .eq("id", participant.competition_id)
    .single();
  if (!comp) return NextResponse.json({ error: "sesi tidak ditemukan" }, { status: 404, headers: NO_CACHE });

  // ambil daftar check aktif dari preset difficulty
  const { data: diff } = await db
    .from("difficulties")
    .select("active_check_codes")
    .eq("key", comp.difficulty)
    .maybeSingle();

  const rawCodes = diff?.active_check_codes;
  const activeCodes: string[] = typeof rawCodes === "string" ? JSON.parse(rawCodes) : (Array.isArray(rawCodes) ? rawCodes : []);

  return NextResponse.json({
    status: comp.status,
    participant_status: participant.status,
    server_time_ms: Date.now(),
    ends_at_ms: comp.ends_at ? new Date(comp.ends_at).getTime() : null,
    difficulty: comp.difficulty,
    hint_policy: comp.hint_policy,
    penalty_weight: comp.penalty_weight,
    active_check_codes: activeCodes,
  }, { headers: NO_CACHE });
}
