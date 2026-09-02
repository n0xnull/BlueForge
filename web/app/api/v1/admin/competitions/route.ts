import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";
import { isAdmin } from "@/lib/auth";

export const dynamic = "force-dynamic";

function genCode(): string {
  const s = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let out = "DHC-";
  for (let i = 0; i < 4; i++) out += s[Math.floor(Math.random() * s.length)];
  return out;
}

// GET /api/v1/admin/competitions — daftar sesi + jumlah peserta
export async function GET(req: NextRequest) {
  if (!isAdmin(req)) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const db = supabaseAdmin();
  const { data: comps } = await db
    .from("competitions")
    .select("*")
    .order("created_at", { ascending: false });

  // hitung peserta per sesi
  const { data: parts } = await db.from("participants").select("competition_id");
  const counts: Record<string, number> = {};
  (parts ?? []).forEach((p: any) => {
    counts[p.competition_id] = (counts[p.competition_id] || 0) + 1;
  });

  const enriched = (comps ?? []).map((c: any) => ({ ...c, participant_count: counts[c.id] || 0 }));
  return NextResponse.json({ competitions: enriched });
}

// POST /api/v1/admin/competitions
//   { action: "create", name, difficulty }
//   { action: "start"|"pause"|"resume"|"stop"|"archive"|"delete", competition_id }
export async function POST(req: NextRequest) {
  if (!isAdmin(req)) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const body = await req.json().catch(() => ({}));
  const db = supabaseAdmin();
  const action = body.action;

  if (action === "create") {
    // Validasi `difficulty` terhadap tabel `difficulties` sendiri (bukan
    // daftar hardcoded ["easy","medium","hard"] seperti sebelumnya) --
    // sebelumnya memilih preset apa pun di luar 3 itu (mis. "fitcom", yang
    // baru ditambah v0.4) akan DIAM-DIAM jatuh ke "easy" tanpa error sama
    // sekali, jadi panitia bisa salah bikin sesi 6-soal padahal mengira
    // sudah memilih FITCOM 30-soal. Sekarang divalidasi dgn query nyata,
    // dan preset baru di masa depan otomatis kepakai tanpa perlu ubah kode.
    let difficulty = String(body.difficulty || "easy");
    let { data: diff } = await db
      .from("difficulties")
      .select("hint_policy,penalty_weight,default_duration_sec")
      .eq("key", difficulty)
      .maybeSingle();
    if (!diff) {
      difficulty = "easy";
      ({ data: diff } = await db
        .from("difficulties")
        .select("hint_policy,penalty_weight,default_duration_sec")
        .eq("key", difficulty)
        .maybeSingle());
    }
    // durasi custom (menit) opsional; kalau kosong pakai default per tingkat
    const mins = Number(body.duration_minutes);
    const durationSec = Number.isFinite(mins) && mins > 0
      ? Math.round(mins * 60)
      : (diff?.default_duration_sec ?? 5400);
    const { data: comp, error } = await db
      .from("competitions")
      .insert({
        name: (body.name || "Lomba DHC").trim(),
        difficulty,
        status: "waiting",
        duration_sec: durationSec,
        hint_policy: diff?.hint_policy ?? "full",
        penalty_weight: diff?.penalty_weight ?? 1.0,
        session_code: genCode(),
      })
      .select("*")
      .single();
    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    return NextResponse.json({ competition: comp });
  }

  const id = body.competition_id;
  if (!id) return NextResponse.json({ error: "competition_id wajib" }, { status: 400 });

  if (action === "delete") {
    const { error } = await db.from("competitions").delete().eq("id", id);
    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    return NextResponse.json({ ok: true, deleted: id });
  }

  const { data: comp } = await db.from("competitions").select("*").eq("id", id).maybeSingle();
  if (!comp) return NextResponse.json({ error: "sesi tidak ditemukan" }, { status: 404 });

  const now = Date.now();
  let patch: any = {};
  if (action === "start") {
    patch = {
      status: "running",
      started_at: new Date(now).toISOString(),
      ends_at: new Date(now + comp.duration_sec * 1000).toISOString(),
    };
  } else if (action === "pause") {
    patch = { status: "paused" };
  } else if (action === "resume") {
    patch = { status: "running" };
  } else if (action === "stop") {
    patch = { status: "ended" };
  } else if (action === "archive") {
    patch = { status: "archived" };
  } else {
    return NextResponse.json({ error: "action tidak dikenal" }, { status: 400 });
  }

  const { data: updated, error } = await db
    .from("competitions").update(patch).eq("id", id).select("*").single();
  if (error) return NextResponse.json({ error: error.message }, { status: 500 });

  await db.from("event_logs").insert({
    competition_id: id, type: `competition_${action}`, level: "AUDIT", payload: patch,
  });
  return NextResponse.json({ competition: updated });
}
