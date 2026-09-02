import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";
import { isAdmin } from "@/lib/auth";

export const dynamic = "force-dynamic";

function csvEscape(v: any): string {
  const s = v === null || v === undefined ? "" : String(v);
  if (/[",\n]/.test(s)) return '"' + s.replace(/"/g, '""') + '"';
  return s;
}

// GET /api/v1/admin/export?comp=<id> — unduh hasil akhir sesi sbg CSV
// (peringkat, nama, sekolah, skor, jumlah soal selesai) untuk sertifikat /
// laporan panitia, tanpa perlu query manual ke Supabase.
// (docs/REVIEW-AND-CONCEPT-v2.md §4.3 -- fitur yang direkomendasikan tapi
// belum ada; ditambahkan di sini.)
export async function GET(req: NextRequest) {
  if (!isAdmin(req)) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const compId = new URL(req.url).searchParams.get("comp");
  if (!compId) return NextResponse.json({ error: "comp wajib" }, { status: 400 });

  const db = supabaseAdmin();
  const { data: comp } = await db
    .from("competitions").select("name, difficulty").eq("id", compId).maybeSingle();
  if (!comp) return NextResponse.json({ error: "sesi tidak ditemukan" }, { status: 404 });

  const { data: rows } = await db
    .from("leaderboard")
    .select("participant_id, full_name, school, status, total_score, rank")
    .eq("competition_id", compId)
    .order("rank", { ascending: true });
  const list = rows ?? [];

  const { data: diff } = await db
    .from("difficulties").select("active_check_codes").eq("key", comp.difficulty).maybeSingle();
  const totalChecks = (diff?.active_check_codes ?? []).length;

  const ids = list.map((r: any) => r.participant_id);
  const pcheckResult = ids.length
    ? await db.from("participant_checks").select("participant_id, passed, eligible").in("participant_id", ids)
    : { data: [] as any[] };
  const passedByParticipant = new Map<string, number>();
  (pcheckResult.data ?? []).forEach((pc: any) => {
    // hanya hitung yang SAH (eligible, bukan pre-fix) -- konsisten dengan
    // apa yang sungguh dapat poin di scoring engine.
    if (pc.passed && pc.eligible !== false) {
      passedByParticipant.set(pc.participant_id, (passedByParticipant.get(pc.participant_id) || 0) + 1);
    }
  });

  const header = ["Peringkat", "Nama", "Sekolah", "Status", "Skor", "Soal Selesai (sah)", "Total Soal"];
  const lines = [header.map(csvEscape).join(",")];
  list.forEach((r: any) => {
    lines.push([
      r.rank, r.full_name, r.school ?? "", r.status, r.total_score,
      passedByParticipant.get(r.participant_id) || 0, totalChecks,
    ].map(csvEscape).join(","));
  });

  // BOM UTF-8 di depan supaya Excel (Windows) menampilkan karakter Indonesia
  // (mis. é, huruf besar/kecil dengan diakritik di nama sekolah) dgn benar.
  const csv = "\uFEFF" + lines.join("\r\n") + "\r\n";
  const filename = `blueforge-${(comp.name || "hasil").replace(/[^a-z0-9]+/gi, "-").toLowerCase()}.csv`;
  return new NextResponse(csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="${filename}"`,
      "Cache-Control": "no-store",
    },
  });
}
