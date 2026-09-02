"use client";
import { Fragment, useEffect, useRef, useState } from "react";
import { supabaseBrowser } from "@/lib/supabase";

type Row = { participant_id: string; full_name: string; school: string | null;
  total_score: number; rank: number; status: string };
type Comp = { id: string; name: string; difficulty: string; status: string;
  ends_at_ms: number | null; server_time_ms: number } | null;
type CheckItem = { code: string; title: string; category: string | null;
  points: number; passed: boolean; eligible?: boolean; scored_points: number };
type Detail = { participant: { full_name: string; school: string | null; status: string };
  difficulty: string | null; passed_count: number; total_count: number; checks: CheckItem[] };

const STATUS_LABEL: Record<string, string> = {
  waiting: "Menunggu", running: "Berlangsung", paused: "Jeda", ended: "Selesai", archived: "Arsip",
};
const DIFF_LABEL: Record<string, string> = { easy: "Mudah", medium: "Medium", hard: "Hard" };
const MEDAL = ["🥇", "🥈", "🥉"];

export default function Leaderboard() {
  const [comp, setComp] = useState<Comp>(null);
  const [rows, setRows] = useState<Row[]>([]);
  const [remaining, setRemaining] = useState<number | null>(null);
  const [loaded, setLoaded] = useState(false);
  const offsetRef = useRef(0);

  // Detail per-check saat baris/skor peserta diklik -- supaya bukan cuma
  // nama & angka total yang kelihatan, tapi transparan soal mana yang sudah
  // benar & mana yang belum (lihat /api/v1/leaderboard/detail).
  const [openId, setOpenId] = useState<string | null>(null);
  const [detailCache, setDetailCache] = useState<Record<string, Detail>>({});
  const [detailLoading, setDetailLoading] = useState<string | null>(null);

  async function toggleDetail(pid: string) {
    if (openId === pid) { setOpenId(null); return; }
    setOpenId(pid);
    if (detailCache[pid]) return; // sudah pernah di-fetch, pakai cache
    setDetailLoading(pid);
    try {
      const r = await fetch(`/api/v1/leaderboard/detail?participant=${pid}`, { cache: "no-store" });
      const j = await r.json();
      setDetailCache((d) => ({ ...d, [pid]: j }));
    } catch { /* diam */ } finally { setDetailLoading((cur) => (cur === pid ? null : cur)); }
  }

  async function load() {
    try {
      const r = await fetch("/api/v1/leaderboard", { cache: "no-store" });
      const j = await r.json();
      setComp(j.competition);
      setRows(j.rows || []);
      if (j.competition?.server_time_ms) offsetRef.current = j.competition.server_time_ms - Date.now();
    } catch { /* diam */ } finally { setLoaded(true); }
  }

  useEffect(() => {
    load();
    const poll = setInterval(load, 4000);
    let channel: any;
    try {
      const sb: any = supabaseBrowser();
      channel = sb.channel("scores-stream")
        .on("postgres_changes", { event: "INSERT", schema: "public", table: "scores" }, load)
        .subscribe();
    } catch { /* realtime opsional */ }
    return () => { clearInterval(poll); try { channel?.unsubscribe(); } catch {} };
  }, []);

  useEffect(() => {
    const t = setInterval(() => {
      if (comp?.status === "running" && comp.ends_at_ms) {
        const now = Date.now() + offsetRef.current;
        setRemaining(Math.max(0, Math.floor((comp.ends_at_ms - now) / 1000)));
      } else setRemaining(null);
    }, 1000);
    return () => clearInterval(t);
  }, [comp]);

  const fmt = (s: number | null) =>
    s == null ? "--:--" : `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;

  return (
    <div className="wrap">
      <div className="topbar">
        <div className="brand">
          <div className="logo"><img src="/blueforge-icon-256.png" alt="BlueForge" /></div>
          <div><h1>BlueForge</h1><div className="sub">Defend · Harden · Compete</div></div>
        </div>
        <a href="/admin" className="badge">Panitia</a>
      </div>

      <div className="card">
        <div className="head">
          <div>
            <div style={{ fontWeight: 800, fontSize: 20 }}>{comp?.name ?? (loaded ? "Belum ada sesi aktif" : "Memuat…")}</div>
            <div className="small muted" style={{ marginTop: 5, display: "flex", gap: 8, alignItems: "center" }}>
              {comp ? (<>
                <span className={"badge " + comp.status}>{STATUS_LABEL[comp.status] ?? comp.status}</span>
                <span>Tingkat {DIFF_LABEL[comp.difficulty] ?? comp.difficulty}</span>
              </>) : "Menunggu panitia membuat & memulai sesi."}
            </div>
          </div>
          <div style={{ textAlign: "right" }}>
            <div className="small muted">SISA WAKTU</div>
            <div className="timer" style={{ color: remaining !== null && remaining < 60 ? "var(--danger)" : "var(--fg)" }}>{fmt(remaining)}</div>
          </div>
        </div>
      </div>

      <div className="card">
        <table>
          <thead><tr><th>#</th><th>Peserta</th><th>Sekolah</th><th style={{ textAlign: "right" }}>Skor</th></tr></thead>
          <tbody>
            {!loaded && [0, 1, 2].map((i) => (
              <tr key={i}>
                <td><div className="skel-row" style={{ width: 20 }} /></td>
                <td><div className="skel-row" style={{ width: 140 }} /></td>
                <td><div className="skel-row" style={{ width: 90 }} /></td>
                <td><div className="skel-row" style={{ width: 50, marginLeft: "auto" }} /></td>
              </tr>
            ))}
            {loaded && rows.length === 0 && <tr><td colSpan={4} className="empty">Belum ada peserta terdaftar.</td></tr>}
            {rows.map((r) => {
              const isOpen = openId === r.participant_id;
              const d = detailCache[r.participant_id];
              const isDq = r.status === "disqualified";
              return (
                <Fragment key={r.participant_id}>
                  <tr className={(r.rank === 1 ? "top1 " : "") + "score-row"}
                    onClick={() => toggleDetail(r.participant_id)} title="Klik untuk lihat rincian soal">
                    <td className="rank">{r.rank <= 3 ? MEDAL[r.rank - 1] : r.rank}</td>
                    <td>
                      <span style={{ fontWeight: 600 }}>{r.full_name}</span>
                      {r.status === "offline" && <span className="small muted"> · offline</span>}
                      {isDq && (
                        <span className="badge" style={{ marginLeft: 8, background: "rgba(255,93,93,.25)", color: "var(--danger)", fontWeight: 800 }}>
                          🚨 DIDISKUALIFIKASI
                        </span>
                      )}
                    </td>
                    <td className="muted">{r.school ?? "—"}</td>
                    <td className="score">
                      {isDq ? (
                        <span style={{ color: "var(--danger)" }}>
                          <s style={{ opacity: 0.7 }}>{r.total_score}</s> <span style={{ fontSize: 12 }}>(DQ)</span>
                        </span>
                      ) : (
                        r.total_score
                      )}
                      <span className="detail-caret">{isOpen ? "▲" : "▼"}</span>
                    </td>
                  </tr>
                  {isOpen && (
                    <tr className="detail-row">
                      <td colSpan={4}>
                        {isDq && (
                          <div style={{ background: "rgba(255,93,93,.16)", border: "1px solid var(--danger)", borderRadius: 8, padding: "8px 12px", color: "var(--danger)", fontWeight: 800, marginBottom: 12 }}>
                            🚨 PESERTA INI TELAH DIDISKUALIFIKASI OLEH PANITIA
                          </div>
                        )}
                        {detailLoading === r.participant_id && !d && (
                          <div className="small muted">Memuat rincian…</div>
                        )}
                        {d && (
                          <>
                            <div className="small muted" style={{ marginBottom: 8 }}>
                              {d.passed_count} / {d.total_count} soal selesai
                            </div>
                            <div className="detail-grid">
                              {d.checks.map((c) => {
                                const isPreFix = c.passed && c.eligible === false;
                                const cls = isPreFix ? "anomaly" : c.passed ? "pass" : "fail";
                                return (
                                  <div key={c.code} className={"detail-item " + cls}
                                    title={isPreFix ? "Lulus sebelum START -- tidak mendapat poin" : undefined}>
                                    <span className="detail-icon">{isPreFix || c.passed ? "✔" : "✗"}</span>
                                    <span>{c.title}</span>
                                    {isPreFix && <span className="small" style={{ color: "var(--danger)", fontWeight: 700, marginLeft: 4 }}>(Pre-fix)</span>}
                                  </div>
                                );
                              })}
                            </div>
                          </>
                        )}
                      </td>
                    </tr>
                  )}
                </Fragment>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="small muted" style={{ textAlign: "center", display: "flex", justifyContent: "center", gap: 8, alignItems: "center" }}>
        <span className="live-tag"><span className="live-dot" /> Live</span>
        <span>· Papan skor memperbarui otomatis · BlueForge</span>
      </div>
    </div>
  );
}
