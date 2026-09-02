import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";

export const dynamic = "force-dynamic";
export const revalidate = 0;

// GET /api/v1/leaderboard/detail?participant=<id>  (publik, read-only)
//
// Rincian per-check untuk SATU peserta: judul soal + status lulus/belum.
// Dipakai leaderboard publik saat baris/skor peserta diklik, supaya panitia
// & sesama peserta bisa lihat transparan "mana yang sudah benar, mana yang
// belum" -- bukan cuma nama & angka total.
//
// Aman dibuka publik: hanya menyertakan judul soal (sama seperti yang sudah
// tampil di kiosk peserta sendiri) + status boolean, TIDAK ada command
// perbaikan/jawaban maupun data sensitif apa pun.
export async function GET(req: NextRequest) {
  const participantId = new URL(req.url).searchParams.get("participant");
  if (!participantId) {
    return NextResponse.json({ error: "participant wajib" }, { status: 400 });
  }

  const db = supabaseAdmin();

  const { data: participant, error: pErr } = await db
    .from("participants")
    .select("id, full_name, school, status, competition_id")
    .eq("id", participantId)
    .maybeSingle();
  if (pErr || !participant) {
    return NextResponse.json({ error: "peserta tidak ditemukan" }, { status: 404 });
  }

  const { data: comp } = await db
    .from("competitions")
    .select("difficulty")
    .eq("id", participant.competition_id)
    .maybeSingle();

  const { data: diff } = await db
    .from("difficulties")
    .select("active_check_codes")
    .eq("key", comp?.difficulty ?? "easy")
    .maybeSingle();
  const activeCodes: string[] = diff?.active_check_codes ?? [];

  const { data: checks } = await db
    .from("checks")
    .select("code, title, points, category")
    .in("code", activeCodes.length ? activeCodes : ["__none__"]);
  const checkByCode = new Map((checks ?? []).map((c) => [c.code, c]));

  const { data: pchecks } = await db
    .from("participant_checks")
    .select("check_code, passed, eligible, scored_points")
    .eq("participant_id", participantId);
  const statusByCode = new Map((pchecks ?? []).map((pc) => [pc.check_code, pc]));

  // urutkan mengikuti urutan asli active_check_codes (konsisten dgn tingkat)
  const items = activeCodes.map((code) => {
    const c = checkByCode.get(code);
    const s = statusByCode.get(code);
    return {
      code,
      title: c?.title ?? code,
      category: c?.category ?? null,
      points: c?.points ?? 10,
      passed: s?.passed ?? false,
      eligible: s ? s.eligible : true,
      scored_points: s?.scored_points ?? 0,
    };
  });

  const passedCount = items.filter((i) => i.passed).length;

  return NextResponse.json({
    participant: {
      id: participant.id,
      full_name: participant.full_name,
      school: participant.school,
      status: participant.status,
    },
    difficulty: comp?.difficulty ?? null,
    passed_count: passedCount,
    total_count: items.length,
    checks: items,
  });
}
