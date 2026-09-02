import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase";
import { verifyAgentRequest } from "@/lib/hmac";

export const dynamic = "force-dynamic";

// POST /api/v1/heartbeat  (TDD §16.5)
export async function POST(req: NextRequest) {
  const raw = await req.text();
  const db = supabaseAdmin();
  const auth = await verifyAgentRequest(req, "/api/v1/heartbeat", raw, db);
  if (!auth.ok) return NextResponse.json({ error: auth.reason }, { status: 401 });

  let body: any = {};
  try { body = JSON.parse(raw || "{}"); } catch { /* ignore */ }

  // PENTING: jangan timpa status peserta yang sudah DIDISKUALIFIKASI oleh
  // panitia. Sebelumnya endpoint ini SELALU menulis status:"online" tanpa
  // syarat apa pun -- akibatnya tombol "DQ" di admin percuma: begitu agent
  // peserta kirim heartbeat berikutnya (siklus poll ~15-20 detik), status
  // langsung balik "online" lagi seolah DQ tak pernah terjadi. Sekarang cek
  // status saat ini dulu, dan skip update kalau sudah disqualified.
  const { data: current } = await db
    .from("participants").select("status").eq("id", auth.participantId).maybeSingle();
  if (!current) return NextResponse.json({ error: "unknown" }, { status: 401 });

  if (current.status === "disqualified") {
    // Balas 200 (bukan error) supaya agent tidak masuk mode retry/backoff
    // sia-sia, tapi TIDAK mengubah apa pun di database. Flag `disqualified`
    // dipakai agent utk berhenti scoring & menampilkan banner di kiosk.
    return NextResponse.json({ ok: true, disqualified: true });
  }

  await db
    .from("participants")
    .update({
      status: "online",
      last_heartbeat: new Date().toISOString(),
      agent_version: body.agent_version ?? null,
    })
    .eq("id", auth.participantId);

  return NextResponse.json({ ok: true });
}
