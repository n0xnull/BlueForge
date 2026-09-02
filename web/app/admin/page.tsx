"use client";
import { Fragment, useEffect, useState } from "react";

type Comp = {
  id: string; name: string; difficulty: string; status: string;
  session_code: string; duration_sec: number; participant_count: number;
};
type PartCheck = { code: string; title: string; passed: boolean; eligible: boolean };
type Part = {
  id: string; full_name: string; school: string | null; status: string;
  agent_version: string | null; last_heartbeat: string | null;
  checks?: PartCheck[]; has_anomaly?: boolean;
};

const DIFF_LABEL: Record<string, string> = { easy: "Mudah", medium: "Medium", hard: "Hard", fitcom: "FITCOM" };
const DIFF_DEFAULT_MIN: Record<string, number> = { easy: 120, medium: 90, hard: 60, fitcom: 150 };

export default function Admin() {
  const [authed, setAuthed] = useState<boolean | null>(null);
  const [pw, setPw] = useState("");
  const [comps, setComps] = useState<Comp[]>([]);
  const [name, setName] = useState("Defense Hardening Competition #1");
  const [difficulty, setDifficulty] = useState("easy");
  const [durationMin, setDurationMin] = useState(120);
  const [openId, setOpenId] = useState<string | null>(null);
  const [parts, setParts] = useState<Part[]>([]);
  const [openParticipantId, setOpenParticipantId] = useState<string | null>(null);
  const [toast, setToast] = useState<{ m: string; k: string } | null>(null);
  const [busy, setBusy] = useState(false);

  function flash(m: string, k = "ok") { setToast({ m, k }); setTimeout(() => setToast(null), 2600); }

  async function checkAuth() {
    const r = await fetch("/api/v1/admin/login", { cache: "no-store" });
    const j = await r.json();
    setAuthed(!!j.authed);
    if (j.authed) loadComps();
  }
  useEffect(() => { checkAuth(); }, []);

  // Auto-refresh: sesi & peserta TIDAK lagi menunggu klik manual (lihat
  // docs/REVIEW-AND-CONCEPT-v2.md §2.2 — sebelumnya panitia harus reload sendiri
  // untuk melihat status online/offline & skor terbaru).
  useEffect(() => {
    if (!authed) return;
    const t = setInterval(() => { if (!busy) loadComps(); }, 5000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [authed, busy]);

  useEffect(() => {
    if (!openId) return;
    const t = setInterval(() => { if (!busy) refreshParts(openId); }, 4000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [openId, busy]);

  async function login() {
    setBusy(true);
    const r = await fetch("/api/v1/admin/login", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ password: pw }),
    });
    setBusy(false);
    if (r.ok) { setAuthed(true); setPw(""); loadComps(); flash("Berhasil masuk"); }
    else {
      const j = await r.json().catch(() => ({}));
      flash(j.error || "Password salah", "err");
    }
  }
  async function logout() {
    await fetch("/api/v1/admin/login", { method: "DELETE" });
    setAuthed(false); setComps([]); setOpenId(null);
  }

  async function loadComps() {
    const r = await fetch("/api/v1/admin/competitions", { cache: "no-store" });
    if (r.status === 401) { setAuthed(false); return; }
    const j = await r.json();
    setComps(j.competitions || []);
  }

  async function comp(action: string, competition_id?: string, extra: any = {}) {
    setBusy(true);
    const r = await fetch("/api/v1/admin/competitions", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action, competition_id, ...extra }),
    });
    setBusy(false);
    const j = await r.json().catch(() => ({}));
    if (!r.ok) { flash(j.error || "Gagal", "err"); return; }
    if (action === "create") flash(`Sesi dibuat: ${j.competition?.session_code}`);
    loadComps();
  }

  function onDifficultyChange(v: string) {
    setDifficulty(v);
    setDurationMin(DIFF_DEFAULT_MIN[v] ?? 90); // isi default; masih bisa diubah manual
  }

  async function toggleParts(id: string) {
    if (openId === id) { setOpenId(null); return; }
    setOpenId(id);
    setOpenParticipantId(null);
    await refreshParts(id);
  }
  async function refreshParts(compId: string) {
    const r = await fetch(`/api/v1/admin/participants?comp=${compId}`, { cache: "no-store" });
    setParts((await r.json()).participants || []);
  }

  // Aksi terhadap 1 peserta (DQ / batalkan DQ / hapus). Sebelumnya fungsi ini
  // tidak pernah mengecek `r.ok` -- jadi kalau request gagal (mis. sesi
  // admin kedaluwarsa, error server), UI tetap menampilkan toast "berhasil"
  // seolah DQ jalan padahal tidak. Itulah salah satu penyebab laporan
  // "tombol DQ tidak work": gagalnya SENYAP. Sekarang error ditampilkan asli.
  async function partAction(action: string, participant_id: string) {
    if (action === "remove" && !confirm("Hapus peserta ini?")) return;
    setBusy(true);
    const r = await fetch("/api/v1/admin/participants", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action, participant_id }),
    });
    setBusy(false);
    const j = await r.json().catch(() => ({}));
    if (!r.ok) { flash(j.error || "Aksi gagal", "err"); return; }
    if (openId) await refreshParts(openId);
    loadComps();
    flash(action === "remove" ? "Peserta dihapus" : action === "disqualify" ? "Peserta didiskualifikasi" : "DQ dibatalkan");
  }

  function toggleParticipantDetail(pid: string) {
    setOpenParticipantId((cur) => (cur === pid ? null : pid));
  }

  // ---------- render ----------
  const Brand = (
    <div className="brand">
      <div className="logo"><img src="/blueforge-icon-256.png" alt="BlueForge" /></div>
      <div><h1>BlueForge · Admin</h1><div className="sub">Kelola lomba & peserta</div></div>
    </div>
  );

  if (authed === null) {
    return <div className="wrap"><div className="empty"><span className="spinner" /> Memuat…</div></div>;
  }

  if (!authed) {
    return (
      <div className="wrap">
        <div className="login">
          {Brand}
          <div className="card" style={{ marginTop: 18 }}>
            <h3>Masuk sebagai Panitia</h3>
            <label>Password Admin</label>
            <input type="password" value={pw} onChange={(e) => setPw(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && login()} placeholder="••••••••" />
            <div className="actions" style={{ marginTop: 14 }}>
              <button onClick={login} disabled={busy}>{busy ? <span className="spinner" /> : "Masuk"}</button>
              <a href="/" style={{ alignSelf: "center" }}>← Leaderboard</a>
            </div>
          </div>
        </div>
        {toast && <div className={"toast " + toast.k}>{toast.m}</div>}
      </div>
    );
  }

  return (
    <div className="wrap">
      <div className="topbar">
        {Brand}
        <div className="actions">
          <a href="/" className="badge ended">Lihat Leaderboard →</a>
          <button className="ghost sm" onClick={logout}>Keluar</button>
        </div>
      </div>

      <div className="card">
        <h3>Buat Sesi Baru</h3>
        <label>Nama lomba</label>
        <input value={name} onChange={(e) => setName(e.target.value)} />
        <div className="grid2" style={{ marginTop: 4 }}>
          <div><label>Tingkat kesulitan</label>
            <select value={difficulty} onChange={(e) => onDifficultyChange(e.target.value)}>
              <option value="easy">Mudah (Easy) · 6 soal</option>
              <option value="medium">Medium · 11 soal</option>
              <option value="hard">Hard · 15 soal</option>
              <option value="fitcom">FITCOM (Event) · 30 soal</option>
            </select></div>
          <div><label>Durasi pengerjaan (menit)</label>
            <input type="number" min={1} value={durationMin}
              onChange={(e) => setDurationMin(Number(e.target.value))} />
            <div className="small muted" style={{ marginTop: 4 }}>Default {DIFF_DEFAULT_MIN[difficulty]} mnt — bisa diubah.</div>
          </div>
        </div>
        <div className="actions" style={{ marginTop: 14 }}>
          <button onClick={() => comp("create", undefined, { name, difficulty, duration_minutes: durationMin })} disabled={busy}>+ Buat Sesi</button>
        </div>
      </div>

      <div className="card">
        <h3>Daftar Sesi ({comps.length}) <span className="live-tag"><span className="live-dot" /> Auto-refresh</span></h3>
        {comps.length === 0 && <div className="empty">Belum ada sesi. Buat satu di atas.</div>}
        {comps.map((c) => (
          <div key={c.id} style={{ borderTop: "1px solid var(--line)", paddingTop: 14, marginTop: 14 }}>
            <div className="head">
              <div>
                <div style={{ fontWeight: 800, fontSize: 15 }}>{c.name}</div>
                <div className="small muted" style={{ marginTop: 4, display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>
                  <span className={"badge " + c.status}>{c.status}</span>
                  <span>Tingkat {DIFF_LABEL[c.difficulty] ?? c.difficulty}</span>·
                  <span>Kode <span className="code">{c.session_code}</span></span>·
                  <span>{Math.round((c.duration_sec ?? 0) / 60)} mnt</span>·
                  <span>{c.participant_count} peserta</span>
                </div>
              </div>
            </div>
            <div className="actions" style={{ marginTop: 12 }}>
              <button className="ok sm" onClick={() => comp("start", c.id)}
                disabled={busy || !["waiting", "paused"].includes(c.status)}>▶ Start</button>
              <button className="warn sm" onClick={() => comp("pause", c.id)}
                disabled={busy || c.status !== "running"}>⏸ Pause</button>
              <button className="sec sm" onClick={() => comp("stop", c.id)}
                disabled={busy || !["running", "paused"].includes(c.status)}>⏹ Stop</button>
              <button className="ghost sm" onClick={() => toggleParts(c.id)}>
                {openId === c.id ? "Tutup peserta" : "Lihat peserta"}</button>
              <a className="ghost sm" style={{ textDecoration: "none" }}
                href={`/api/v1/admin/export?comp=${c.id}`} target="_blank" rel="noreferrer">⬇ Export CSV</a>
              <button className="ghost sm" onClick={() => comp("archive", c.id)}
                disabled={busy || c.status === "archived"}>Arsipkan</button>
              <button className="danger sm" onClick={() => { if (confirm("Hapus sesi ini beserta semua pesertanya?")) comp("delete", c.id); }}>
                Hapus</button>
            </div>

            {openId === c.id && (
              <div style={{ marginTop: 12, background: "var(--bg2)", borderRadius: 10, padding: 4 }}>
                {parts.length === 0 ? <div className="empty small">Belum ada peserta.</div> : (
                  <table>
                    <thead><tr><th>Peserta</th><th>Sekolah</th><th>Status</th><th></th></tr></thead>
                    <tbody>
                      {parts.map((p) => {
                        const detailOpen = openParticipantId === p.id;
                        return (
                        <Fragment key={p.id}>
                          <tr>
                            <td>
                              <span style={{ cursor: p.checks?.length ? "pointer" : "default" }}
                                onClick={() => p.checks?.length && toggleParticipantDetail(p.id)}
                                title={p.checks?.length ? "Klik untuk lihat rincian soal" : undefined}>
                                {p.full_name}
                                {p.checks?.length ? <span className="detail-caret">{detailOpen ? "▲" : "▼"}</span> : null}
                              </span>
                              {p.has_anomaly && (
                                <span className="badge" style={{ marginLeft: 8, background: "rgba(255,93,93,.16)", color: "var(--danger)" }}
                                  title="Ada soal yang sudah LULUS sebelum panitia klik START -- indikasi peserta mengerjakan lebih dulu (curang/pre-fix). Poinnya sendiri sudah otomatis TIDAK dihitung, ini cuma penanda visual.">
                                  ⚠ Anomali start
                                </span>
                              )}
                            </td>
                            <td className="muted">{p.school || "—"}</td>
                            <td><span className={"badge " + (p.status === "online" ? "running" : p.status === "disqualified" ? "archived" : "paused")}>{p.status}</span></td>
                            <td style={{ textAlign: "right" }}>
                              <div className="actions" style={{ justifyContent: "flex-end" }}>
                                {p.status === "disqualified" ? (
                                  <button className="ok sm" onClick={() => partAction("requalify", p.id)}>Batalkan DQ</button>
                                ) : (
                                  <button className="warn sm" onClick={() => partAction("disqualify", p.id)}>DQ</button>
                                )}
                                <button className="danger sm" onClick={() => partAction("remove", p.id)}>Hapus</button>
                              </div>
                            </td>
                          </tr>
                          {detailOpen && p.checks?.length ? (
                            <tr className="detail-row">
                              <td colSpan={4}>
                                <div className="small muted" style={{ marginBottom: 8 }}>
                                  {p.checks.filter((c) => c.passed).length} / {p.checks.length} soal selesai
                                  {p.has_anomaly && (
                                    <span style={{ color: "var(--danger)" }}> · centang MERAH = lulus sebelum START (tidak dapat poin)</span>
                                  )}
                                </div>
                                <div className="detail-grid">
                                  {p.checks.map((c, i) => {
                                    const anomaly = c.eligible === false;
                                    const cls = anomaly ? "anomaly" : c.passed ? "pass" : "fail";
                                    return (
                                       <div key={c.code} className={"detail-item " + cls}
                                         title={anomaly ? "Lulus sebelum START -- eligible=false, tidak dapat poin" : undefined}>
                                         <span className="detail-icon">{anomaly || c.passed ? "✔" : "✗"}</span>
                                         <span className="detail-no">{i + 1}.</span>
                                         <span>{c.title}</span>
                                         {anomaly && <span className="small" style={{ color: "var(--danger)", fontWeight: 700, marginLeft: 4 }}>(Pre-fix)</span>}
                                       </div>
                                    );
                                  })}
                                </div>
                              </td>
                            </tr>
                          ) : null}
                        </Fragment>
                        );
                      })}
                    </tbody>
                  </table>
                )}
              </div>
            )}
          </div>
        ))}
      </div>

      {toast && <div className={"toast " + toast.k}>{toast.m}</div>}
    </div>
  );
}
