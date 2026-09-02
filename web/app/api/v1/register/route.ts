import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";
import { deriveSecret, sha256 } from "@/lib/hmac";
import crypto from "crypto";

export const dynamic = "force-dynamic";

// POST /api/v1/register  (TDD §16.1)
export async function POST(req: NextRequest) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "invalid json" }, { status: 400 });
  }
  const name = (body.name || "").trim();
  const school = (body.school || "").trim();
  const sessionCode = (body.session_code || "").trim();
  if (!name || !sessionCode) {
    return NextResponse.json({ error: "name & session_code wajib" }, { status: 400 });
  }

  const db = supabaseAdmin();

  // cari sesi by kode
  const { data: comp } = await db
    .from("competitions")
    .select("id,status,difficulty,hint_policy")
    .eq("session_code", sessionCode)
    .maybeSingle();

  if (!comp) {
    return NextResponse.json({ error: "kode sesi tidak ditemukan" }, { status: 404 });
  }
  if (!["waiting", "running"].includes(comp.status)) {
    return NextResponse.json({ error: "sesi belum dibuka / sudah selesai" }, { status: 409 });
  }

  // buat peserta
  const token = crypto.randomBytes(24).toString("hex");
  const { data: participant, error } = await db
    .from("participants")
    .insert({
      competition_id: comp.id,
      full_name: name,
      school: school || null,
      agent_token_hash: sha256(token),
      agent_secret_hash: "derived", // secret diturunkan dari participant_id (TDD §11)
      status: "online",
      last_heartbeat: new Date().toISOString(),
    })
    .select("id")
    .single();

  if (error || !participant) {
    // Konflik unik (competition_id, full_name, school) KEMUNGKINAN BESAR
    // bukan "curang daftar dua kali" -- lebih sering ini peserta yang SAMA
    // mencoba RESUME: agen di VM-nya sempat crash/di-reboot (peserta pegang
    // akses sudo penuh selama 2.5 jam, restart VM bukan skenario aneh) dan
    // file sesi lokal di agen hilang, jadi kiosk menampilkan form
    // registrasi lagi. Kalau kita tolak mentah-mentah dengan 409 di sini
    // seperti sebelumnya, peserta itu TERKUNCI dari sisa lomba sampai
    // panitia turun tangan manual ke database -- risiko nyata, bukan
    // teoretis. Baris agent_secret sengaja TIDAK disimpan di DB (lihat
    // deriveSecret) justru supaya bisa diturunkan ulang secara deterministik
    // di sini tanpa perlu tabel/API tambahan.
    //
    // Jadi: kalau ini benar unique-violation Postgres (23505) DAN baris
    // lama untuk (competition_id, full_name, school) itu MASIH ADA (belum
    // dihapus panitia) DAN statusnya BUKAN disqualified, perlakukan sebagai
    // resume -- kembalikan kredensial peserta yang SAMA. Peserta yang
    // sudah didiskualifikasi TETAP ditolak di sini, supaya "daftar ulang"
    // tidak bisa dipakai untuk melewati DQ (lihat juga fix DQ di
    // heartbeat/score/state route -- jangan buka lagi celah yang sama
    // lewat jalur register).
    const pgCode = (error as any)?.code;
    if (pgCode === "23505") {
      let existingQuery = db
        .from("participants")
        .select("id, status")
        .eq("competition_id", comp.id)
        .eq("full_name", name);
      existingQuery = school ? existingQuery.eq("school", school) : existingQuery.is("school", null);
      const { data: existing } = await existingQuery.maybeSingle();

      if (existing?.status === "disqualified") {
        return NextResponse.json(
          { error: "Peserta ini sudah didiskualifikasi panitia dan tidak bisa mendaftar ulang. Hubungi panitia." },
          { status: 403 }
        );
      }
      if (existing) {
        const resumedSecret = deriveSecret(existing.id);
        await db.from("event_logs").insert({
          competition_id: comp.id,
          participant_id: existing.id,
          type: "register_resumed",
          level: "AUDIT",
          payload: { name, school, reason: "unique_conflict_treated_as_resume" },
        });
        return NextResponse.json({
          participant_id: existing.id,
          agent_token: token,
          agent_secret: resumedSecret,
          competition_id: comp.id,
          status: comp.status,
          resumed: true,
        });
      }
    }
    return NextResponse.json({ error: "peserta sudah terdaftar / gagal", detail: error?.message }, { status: 409 });
  }

  const secret = deriveSecret(participant.id);

  await db.from("event_logs").insert({
    competition_id: comp.id,
    participant_id: participant.id,
    type: "register",
    level: "AUDIT",
    payload: { name, school },
  });

  return NextResponse.json({
    participant_id: participant.id,
    agent_token: token,
    agent_secret: secret,
    competition_id: comp.id,
    status: comp.status,
  });
}
