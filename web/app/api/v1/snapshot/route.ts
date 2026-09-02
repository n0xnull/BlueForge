import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";
import { verifyAgentRequest } from "@/lib/hmac";

export const dynamic = "force-dynamic";

// POST /api/v1/snapshot  (TDD §16.4, §13 Baseline & Evidence)
export async function POST(req: NextRequest) {
  const raw = await req.text();
  const db = supabaseAdmin();
  const auth = await verifyAgentRequest(req, "/api/v1/snapshot", raw, db);
  if (!auth.ok) return NextResponse.json({ error: auth.reason }, { status: 401 });

  let snap: any;
  try { snap = JSON.parse(raw); } catch { return NextResponse.json({ error: "bad json" }, { status: 400 }); }
  const { data: participant } = await db
    .from("participants")
    .select("id,competition_id")
    .eq("id", auth.participantId)
    .maybeSingle();
  if (!participant) return NextResponse.json({ error: "unknown" }, { status: 401 });

  const phase = snap.phase;
  const checksState: { code: string; passed: boolean }[] = snap.checks_state || [];

  // simpan snapshot (append-only)
  const { data: inserted, error } = await db.from("snapshots").insert({
    participant_id: participant.id,
    phase,
    server_time_ms: Date.now(),
    checks_state: checksState,
    artifacts: snap.artifacts || {},
    signature: req.headers.get("x-signature"),
  }).select("id").single();
  if (error || !inserted) return NextResponse.json({ error: error?.message ?? "gagal simpan snapshot" }, { status: 500 });

  // === BASELINE & ELIGIBILITY (fase start) — TDD §13 ===
  if (phase === "start") {
    for (const c of checksState) {
      // eligible = check GAGAL saat start (kalau sudah lulus => pre-fix => tak diskor)
      const eligible = c.passed === false;
      await db.from("participant_checks").upsert(
        {
          participant_id: participant.id,
          check_code: c.code,
          passed: c.passed,
          eligible,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "participant_id,check_code" }
      );
      if (!eligible) {
        // anomali: sudah lulus sebelum START (indikasi pre-fix)
        await db.from("event_logs").insert({
          competition_id: participant.competition_id,
          participant_id: participant.id,
          type: "baseline_anomaly",
          level: "SECURITY",
          payload: { code: c.code, expected: "fail_at_start", got: "pass" },
        });
      }
    }
  }

  return NextResponse.json({ stored: true, snapshot_id: inserted.id });
}
