import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";
import { isAdmin } from "@/lib/auth";

export const dynamic = "force-dynamic";

// GET /api/v1/admin/participants?comp=<id> — daftar peserta sebuah sesi,
// termasuk rincian per-check (title, passed, eligible) supaya panitia bisa
// lihat indikator anti-curang langsung di fitur "Lihat peserta" -- lihat
// `has_anomaly` & field `eligible` di bawah.
//
// `eligible` di sini berasal dari participant_checks.eligible yang di-set
// server saat fase snapshot START (web/app/api/v1/snapshot/route.ts):
// eligible=false berarti check itu SUDAH LULUS sebelum panitia klik START
// (indikasi peserta mengerjakan lebih dulu / "curang" pre-fix). Baris itu
// TETAP ditandai eligible=false meski `passed` sekarang true -- itulah yang
// dipakai UI utk menampilkan centang MERAH walau soalnya "sudah selesai".
export async function GET(req: NextRequest) {
  if (!isAdmin(req)) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const compId = new URL(req.url).searchParams.get("comp");
  if (!compId) return NextResponse.json({ participants: [] });

  const db = supabaseAdmin();
  const { data: participants } = await db
    .from("participants")
    .select("id, full_name, school, status, agent_version, last_heartbeat, created_at")
    .eq("competition_id", compId)
    .order("created_at", { ascending: true });

  const list = participants ?? [];
  if (list.length === 0) return NextResponse.json({ participants: [] });

  const { data: comp } = await db
    .from("competitions").select("difficulty").eq("id", compId).maybeSingle();
  const { data: diff } = await db
    .from("difficulties").select("active_check_codes").eq("key", comp?.difficulty ?? "easy").maybeSingle();
  const activeCodes: string[] = diff?.active_check_codes ?? [];

  const { data: checksMeta } = await db
    .from("checks").select("code, title")
    .in("code", activeCodes.length ? activeCodes : ["__none__"]);
  const titleByCode = new Map((checksMeta ?? []).map((c: any) => [c.code, c.title]));

  const participantIds = list.map((p: any) => p.id);
  const { data: pchecks } = await db
    .from("participant_checks")
    .select("participant_id, check_code, passed, eligible")
    .in("participant_id", participantIds);

  const byParticipant = new Map<string, any[]>();
  (pchecks ?? []).forEach((pc: any) => {
    if (!byParticipant.has(pc.participant_id)) byParticipant.set(pc.participant_id, []);
    byParticipant.get(pc.participant_id)!.push(pc);
  });

  const enriched = list.map((p: any) => {
    const rows = byParticipant.get(p.id) ?? [];
    const statusByCode = new Map(rows.map((r: any) => [r.check_code, r]));
    const checks = activeCodes.map((code) => {
      const r: any = statusByCode.get(code);
      return {
        code,
        title: titleByCode.get(code) ?? code,
        passed: r?.passed ?? false,
        // belum ada baris (belum pernah di-snapshot START) -> jangan tandai
        // curang, anggap eligible dulu; baru "merah" kalau server EKSPLISIT
        // set eligible=false saat START.
        eligible: r ? !!r.eligible : true,
      };
    });
    const has_anomaly = checks.some((c) => c.eligible === false);
    return { ...p, checks, has_anomaly };
  });

  return NextResponse.json({ participants: enriched });
}

// POST /api/v1/admin/participants  { action: "disqualify"|"requalify"|"remove", participant_id }
export async function POST(req: NextRequest) {
  if (!isAdmin(req)) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const body = await req.json().catch(() => ({}));
  const db = supabaseAdmin();
  const pid = body.participant_id;
  if (!pid) return NextResponse.json({ error: "participant_id wajib" }, { status: 400 });

  const { data: participant } = await db
    .from("participants")
    .select("id, competition_id, full_name, status")
    .eq("id", pid)
    .maybeSingle();
  if (!participant) return NextResponse.json({ error: "peserta tidak ditemukan" }, { status: 404 });

  if (body.action === "remove") {
    const { error } = await db.from("participants").delete().eq("id", pid);
    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    // participant_id null (baris peserta sudah dihapus) -- tetap catat nama
    // di payload demi jejak audit.
    await db.from("event_logs").insert({
      competition_id: participant.competition_id, participant_id: null,
      type: "participant_removed", level: "AUDIT",
      payload: { full_name: participant.full_name },
    });
    return NextResponse.json({ ok: true });
  }

  if (body.action === "disqualify") {
    const { error } = await db.from("participants").update({ status: "disqualified" }).eq("id", pid);
    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    await db.from("event_logs").insert({
      competition_id: participant.competition_id, participant_id: pid,
      type: "participant_disqualified", level: "SECURITY",
      payload: { full_name: participant.full_name, previous_status: participant.status },
    });
    return NextResponse.json({ ok: true });
  }

  if (body.action === "requalify") {
    // batalkan diskualifikasi (mis. tidak sengaja ter-klik) -> kembali online
    const { error } = await db.from("participants").update({ status: "online" }).eq("id", pid);
    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    await db.from("event_logs").insert({
      competition_id: participant.competition_id, participant_id: pid,
      type: "participant_requalified", level: "AUDIT",
      payload: { full_name: participant.full_name },
    });
    return NextResponse.json({ ok: true });
  }

  return NextResponse.json({ error: "action tidak dikenal" }, { status: 400 });
}
