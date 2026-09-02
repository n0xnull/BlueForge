import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";
import { verifyAgentRequest } from "@/lib/hmac";

export const dynamic = "force-dynamic";

// POST /api/v1/score  (TDD §16.3)
export async function POST(req: NextRequest) {
  const raw = await req.text();
  const db = supabaseAdmin();
  const auth = await verifyAgentRequest(req, "/api/v1/score", raw, db);
  if (!auth.ok) return NextResponse.json({ error: auth.reason }, { status: 401 });

  let body: any;
  try { body = JSON.parse(raw); } catch { return NextResponse.json({ error: "bad json" }, { status: 400 }); }
  const { data: participant } = await db
    .from("participants")
    .select("id,competition_id,status")
    .eq("id", auth.participantId)
    .maybeSingle();
  if (!participant) return NextResponse.json({ error: "unknown" }, { status: 401 });

  // Peserta yang sudah didiskualifikasi TIDAK BOLEH terus menambah skor --
  // sebelumnya endpoint ini hanya mengecek status SESI ("running"), bukan
  // status PESERTA, jadi diskualifikasi tidak benar-benar menghentikan apa
  // pun secara fungsional selain warna badge di admin (yang toh langsung
  // ketimpa lagi oleh heartbeat -- lihat perbaikan di heartbeat/route.ts).
  if (participant.status === "disqualified") {
    return NextResponse.json({ accepted: false, reason: "disqualified" }, { status: 403 });
  }

  const { data: comp } = await db
    .from("competitions")
    .select("status")
    .eq("id", participant.competition_id)
    .single();
  if (!comp) return NextResponse.json({ error: "sesi tidak ditemukan" }, { status: 404 });

  // skor hanya diterima saat RUNNING (scoring window)
  if (comp.status !== "running") {
    return NextResponse.json({ accepted: false, reason: "not running" }, { status: 409 });
  }

  const total = Number(body.total_score) || 0;
  const computedAt = Number(body.computed_at_ms) || Date.now();

  // insert idempoten (unique participant_id+computed_at_ms)
  const { error: scoreErr } = await db.from("scores").insert({
    participant_id: participant.id,
    total_score: total,
    computed_at_ms: computedAt,
  });
  if (scoreErr && !scoreErr.message.includes("duplicate")) {
    return NextResponse.json({ error: scoreErr.message }, { status: 500 });
  }

  // update status check terkini (upsert per code)
  if (Array.isArray(body.checks)) {
    for (const c of body.checks) {
      await db.from("participant_checks").upsert(
        {
          participant_id: participant.id,
          check_code: c.code,
          passed: !!c.passed,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "participant_id,check_code" }
      );
    }
  }

  return NextResponse.json({ accepted: true });
}
