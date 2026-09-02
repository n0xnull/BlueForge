<div align="center">

<img src="assets/blueforge-icon-256.png" alt="BlueForge" width="120"/>

# 🛡️ BlueForge

### Defensive Hardening Competition Platform — *defend the box, not just capture the flag.*

Point a class of Ubuntu VMs at a scoring server, let participants patch
real vulnerabilities under a clock, and watch the leaderboard update **live**
as each fix lands — automatically, no manual refresh, no spreadsheet grading.
Free and open source, self-hosted on Vercel + Supabase.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%20VM%20%2B%20Web-blue.svg)]()
[![Python](https://img.shields.io/badge/agent-Python%203.10%2B-3776ab.svg)]()
[![Next.js](https://img.shields.io/badge/web-Next.js%20%2F%20Vercel-black.svg)](https://vercel.com)
[![Supabase](https://img.shields.io/badge/db-Supabase%20Realtime-3fcf8e.svg)](https://supabase.com)
[![Build](https://img.shields.io/github/actions/workflow/status/n0xnull/BlueForge/ci.yml)]()
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Abil%20Khosim-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/abil-khosim-itsec/)

<img src="assets/blueforge-horizontal-1200.png" alt="BlueForge" width="520"/>

[⬇️ Quickstart](#-quickstart) · [✨ Features](#-key-features) · [⚙️ How it works](#️-how-it-works) · [📖 Technical Design](docs/TECHNICAL-DESIGN.md) · [🧯 Troubleshooting](#-troubleshooting-organizer--participant-vm) · [⚠️ Disclaimer](DISCLAIMER.md)

</div>

---

## 🧩 The Problem

Most "cybersecurity competition" tooling is either offense-only (CTF flags,
attack ranges) or a pile of manual work for organizers: someone has to walk
around with a checklist, SSH into every VM, and grade hardening steps by
hand. Scores land minutes or hours after the fact, and participants get no
live feedback on what they've actually fixed.

**BlueForge** is a **defensive** (blue-team / system-hardening)
competition platform, closer to CyberPatriot than to a red-team CTF.
Participants receive a deliberately-vulnerable Ubuntu VM and a time limit;
every genuine fix — SSH hardened, firewall enabled, rogue accounts removed,
backdoors cleaned up — is detected automatically by a lightweight agent and
reflected on a public leaderboard within seconds, no grader required.

## ✨ Key Features

- 🎯 **Four difficulty tiers, 30 checks total** — Easy (6) · Medium (11) ·
  Hard (15) · **FITCOM** (all 30, sized for a real ~2.5h event), picked per
  session by the organizer. Checks run **No. 1 → 30 in genuine
  easiest-to-hardest order**, not just a random or insertion-order list —
  both the kiosk and the admin panel display that exact number next to
  every question.
- 💡 **Hints that guide, never answer** — only a minority of checks
  (~25%) carry a hint at all, and every hint is deliberately *directional*
  ("check what's listening on your network ports") rather than a
  copy-pasteable command. There is no hint tier that hands out the literal
  fix.
- ⚖️ **Fair & evidence-backed anti-cheat** — a Baseline & Evidence system
  snapshots each VM at registration/START/STOP, so fixing a check *before*
  START doesn't earn points (closes the "pre-fix" loophole). This isn't just
  enforced silently server-side: the admin's participant view marks any
  such check with a **red checkmark + "anomaly" badge**, so organizers can
  actually see who tried to pre-fix before deciding on further action.
- 🚫 **Disqualify that actually sticks** — clicking DQ freezes a
  participant's status for good: the agent stops scoring, the participant's
  own kiosk shows a clear "disqualified" banner, and every layer (heartbeat,
  score submission, even re-registration) is blocked from silently
  reversing it.
- ⚡ **Truly live scoring** — leaderboard polls + Supabase Realtime, admin
  console auto-refreshes participant status, and the agent's clock-skew
  correction means scores keep flowing even when a cloned VM's system clock
  is wrong (see [`docs/REVIEW-AND-CONCEPT-v2.md`](docs/REVIEW-AND-CONCEPT-v2.md) §2.1) —
  no more waiting on a manual VMware/Ubuntu clock refresh.
- 🧩 **Modular checks** — add a new hardening check by dropping a
  `manifest.yaml` + `check.py` into `agent/checks/`; the scoring engine never
  needs to change (plugin-style).
- 🖥️ **Zero-setup, crash-resilient participant experience** — the agent
  ships as a kiosk companion app (pywebview, with a browser-kiosk fallback)
  that autostarts on VM boot: participants see registration, live score,
  and remaining time without touching a terminal. Because participants hold
  full `sudo` on their own VM for the whole round, a crash or `sudo reboot`
  is expected, not exceptional — the agent persists its session locally and
  resumes automatically, and the server treats a matching re-registration as
  a resume rather than a rejection, so nobody gets locked out of their own
  progress (disqualified participants are still correctly blocked from this
  path).
- 🔒 **Signed, replay-resistant networking** — HMAC-signed agent↔server
  traffic with a nonce store that rejects replayed requests, exponential
  backoff, and store-and-forward queuing so a flaky network during a
  competition never silently drops a score.
- 🛠️ **Hardened organizer console** — brute-force-limited admin login
  (rate-limited, durably logged), a one-click CSV export of final
  standings, and a full audit trail (`event_logs`) of every disqualify,
  requalify, and removal.
- 🆓 **100% free stack** — Vercel (web) + Supabase (Postgres/Realtime/Auth) +
  a pure-Python agent. No paid services required to run a competition.

## 🖼️ Screenshots

<div align="center">

**Live demo** — a participant's fix lands, the kiosk score updates instantly, and the public leaderboard catches up moments later — no manual refresh anywhere.

<img src="assets/0-live-demo.gif" alt="BlueForge — live scoring demo" width="820"/>

**Leaderboard** — live rank, score, and countdown, no refresh needed.

<img src="assets/2-leaderboard%20peserta.png" alt="BlueForge — leaderboard" width="820"/>

*Detailed score checklist is available by clicking a participant on the public leaderboard:*

<img src="assets/7-leaderboard-score-detail.png" alt="BlueForge — leaderboard score detail" width="820"/>

**Admin console** — create sessions, start/pause/stop, manage participants, auto-refreshing.

<img src="assets/1-dashboard%20web%20admin.png" alt="BlueForge — admin dashboard" width="820"/>
<img src="assets/4-dashboard%20create%20sesi.png" alt="BlueForge — create session" width="820"/>

**Participant kiosk** — a companion window (not fullscreen-lock), so participants can still use the terminal to work while registering and tracking their score live.

<img src="assets/3-tampilan%20blueforge%20agent%20di%20vm.png" alt="BlueForge — kiosk companion window" width="820"/>

<img src="assets/5-pendaftaran%20peserta.png" alt="BlueForge — kiosk registration" width="410"/>
<img src="assets/6-soal%20dan%20pertandingan.png" alt="BlueForge — kiosk dashboard checklist" width="410"/>

</div>

## 💻 System Requirements

| | Organizer (web) | Participant (per VM) |
|---|---|---|
| Hosting | Free Vercel + Supabase project | — |
| OS | — | Ubuntu (20.04–26.04), provisioned via `image/build/provision.sh` |
| Runtime | Node.js 20+ (dev/build only — Vercel builds in the cloud) | Python 3.10+, root access (reads `/etc/shadow` etc.) |
| Network | Public HTTPS endpoint (Vercel) | Outbound HTTPS to that endpoint — agent only *polls out*, so it works fine behind NAT |

## 📦 Download VM Image

> Pre-built VMware image — import and run, no manual provisioning needed.

| File | Link |
|---|---|
| 🖥️ **BlueForge VM (VMware .ova)** | [⬇️ Download via Google Drive](https://tinyurl.com/BlueForge-VMWare) |
| 🔧 **VMware Workstation Player** | [vmware.com/products/workstation-player](https://www.vmware.com/products/workstation-player.html) *(free for non-commercial use)* |

**Import the VM:**
1. Open VMware → **File → Open** → select the `.ova` file.
2. Import → start the VM.
3. Boot → BlueForge kiosk launches automatically. Fill in name + session code from your organizer.

> **Organizer only:** after import, run `sudo bash ~/BlueForge/image/build/provision.sh` once to plant the intentional vulnerabilities before distributing the VM to participants.

---

## 🚀 Quickstart

### 1. Database (Supabase)
1. Create a free project at [supabase.com](https://supabase.com).
2. In **SQL Editor**, run `db/schema.sql`, then `db/seed/difficulties.sql`
   (brand-new project — this alone gives you all 4 tiers, including FITCOM).
   Upgrading an **existing** database from before the FITCOM preset existed?
   Run the relevant file(s) in `db/migrations/` first, then re-run
   `db/seed/difficulties.sql` (it's UPSERT-based, safe to run again anytime).
3. Note your **Project URL**, **anon key**, and **service_role key** (Settings → API).

### 2. Web portal (Next.js)
```bash
cd web
cp .env.example .env.local      # fill in Supabase creds + AGENT_HMAC_SECRET
npm install
npm run dev                     # http://localhost:3000
```
Deploy to Vercel: import the repo → set root directory to `web/` → fill in
the environment variables.

### 3. Agent (inside each participant's Ubuntu VM)
```bash
cd agent
cp config.example.yaml config.yaml   # set portal_url to your deployed web URL
pip install -r requirements.txt
sudo python3 main.py                 # open http://localhost:9090 to register
```
Or launch the kiosk companion app instead of the bare agent:
`python3 kiosk.py` (see [`docs/kiosk-setup.md`](docs/kiosk-setup.md) for
autostart on VM boot).

### 4. Run a competition
1. On **`/admin`**: create a session, pick a difficulty (Easy/Medium/Hard/**FITCOM**), get a **session code**.
2. Participants register at `localhost:9090` using that code.
3. Organizer clicks **START** → every agent begins scoring simultaneously → live scores on **`/`**.
4. **STOP** freezes scores → export results.

> 🧭 First time self-hosting this end-to-end (repo → Supabase → Vercel → VM)?
> See the detailed beginner walkthrough: [`docs/DEPLOYMENT-GUIDE.md`](docs/DEPLOYMENT-GUIDE.md).

## 🎛️ What Each Piece Does

| Component | What it does |
|---|---|
| `agent/` | Python agent — runs checks, computes score, signs & sends results, serves the local kiosk UI |
| `web/app/api/v1/*` | Signed agent-facing API — register, state, score, heartbeat, snapshot, clock sync |
| `web/app/page.tsx` | Public live leaderboard |
| `web/app/admin/page.tsx` | Organizer console — sessions, participants, start/pause/stop, disqualify |
| `db/` | Postgres schema + seed (difficulties, checks) + `leaderboard` view |
| `db/migrations/` | Incremental SQL migrations for databases created before a schema change (e.g. adding the `fitcom` preset) |
| `image/build/provision.sh` | Plants all 30 intentional vulnerabilities into a base Ubuntu VM (idempotent — safe to re-run) |

## ⚙️ How it Works

```
[ participant VM: blueforge-agent ] --HTTPS (polling, signed)--> [ Next.js /v1 API ]
                                                                          |
                                                                   [ Supabase: Postgres + Realtime ]
                                                                          |
                                                        [ Web: live Leaderboard + Admin console ]
```

The agent sits behind NAT and only *polls out* — the server never needs to
reach into a participant's VM. Every scoring cycle: sync clock with the
server (no manual clock fixing needed) → fetch competition state → run the
active checks → compute the score (pure function, `eligible = failed at
START`) → sign and send. Full design in
[`docs/TECHNICAL-DESIGN.md`](docs/TECHNICAL-DESIGN.md).

## 🗺️ Roadmap

- **v0.2** — 15 checks across 3 real difficulty tiers, kiosk companion app, admin auto-refresh, agent clock-skew fix.
- **v0.4** *(current)* — 30 checks total (+15 new), a dedicated **FITCOM**
  preset (all 30, sized for a ~2.5h event) with checks in genuine
  easiest-to-hardest order, guiding-only hints on ~25% of checks, admin
  anti-cheat indicators (red checkmark for pre-fix), a disqualify flow that
  actually sticks, nonce anti-replay, admin login rate limiting, CSV export,
  and an agent that survives a participant's VM crashing or rebooting
  mid-round without losing their session.
- **Next up** — richer plugin API for community-contributed checks, an
  evidence viewer UI, Windows participant VM support (agent port), and a Go
  rewrite of the agent for a smaller footprint.
- **v1.0** — production hardening: multi-organizer orgs, PDF export, a
  fuller admin audit UI on top of the `event_logs` trail that already exists.

See [`docs/V0.2-PLAN.md`](docs/V0.2-PLAN.md), [`CHANGELOG.md`](CHANGELOG.md),
and the full TDD roadmap (§29) for details.

## 🤝 Contributing & Security

Issues and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Add a new
check by subclassing the `run(ctx) -> {"passed": bool, "evidence": {...}}`
contract in `agent/checks/<code>/check.py`; the engine needs no other change.

Found a vulnerability in the platform itself (not one of the intentionally
planted training vulnerabilities)? Report it via [SECURITY.md](SECURITY.md) —
please don't open a public issue.

## 🧯 Troubleshooting (Organizer / Participant VM)

Quick reference for the two operations organizers run most often on a
participant VM. Full step-by-step (Bahasa Indonesia) lives in
[`docs/DEPLOYMENT-GUIDE.md`](docs/DEPLOYMENT-GUIDE.md#-troubleshooting).

**First run on a fresh VM clone:**
```bash
cd ~/BlueForge
git pull
sudo bash image/build/provision.sh   # plants all 30 intentional vulnerabilities
```
`provision.sh` clears `~/.bash_history` (root & the login user) as its very
last step, so a cloned/exported VM doesn't leak the organizer's setup
commands to participants — no separate manual history-clearing step needed
anymore. If you keep typing commands in that same terminal *after*
`provision.sh` finishes and before exporting the VM, run `history -c` once
more right before export — bash can otherwise re-write the still-running
session's history back to the file on a normal shell exit.

**Pulling a code update onto an already-installed VM** — the kiosk/agent
that actually runs at boot is a **separate copy** installed to
`/opt/blueforge-agent/` by `install-kiosk.sh`, not the git checkout itself.
`git pull` alone does **not** update what's running — you must resync:
```bash
cd ~/BlueForge
git pull
sudo bash agent/kiosk/install-kiosk.sh   # resyncs code into /opt + restarts the service
sudo systemctl restart blueforge-agent
```

**Kiosk window accidentally closed by a participant:** `kiosk.py` now
auto-reopens the window on its own within ~2 seconds — no action needed. If
the window is ever truly stuck, double-click the **"Restart BlueForge"**
shortcut on the Desktop (no terminal required), or run
`bash /opt/blueforge-agent/kiosk/restart-kiosk.sh`.

**Common diagnostic commands:**
```bash
systemctl status blueforge-agent dhc-telnetd   # are the services alive?
ps aux | grep -E "kiosk.py|main.py"            # is the kiosk/agent actually running?
journalctl --user -b | grep -i -E "kiosk|webview|gtk"  # kiosk autostart logs this boot
diff ~/BlueForge/agent/kiosk.py /opt/blueforge-agent/kiosk.py  # in sync?
```

## ⚠️ Disclaimer

This platform intentionally plants security vulnerabilities into VMs for
training purposes. **Isolated/air-gapped competition networks only** — see
[DISCLAIMER.md](DISCLAIMER.md) before deploying.

## 📄 License

[MIT](LICENSE) © 2026 Abil Khosim.

---

<!-- GitHub topics: cybersecurity, blue-team, ctf, cyberpatriot, defensive-security,
system-hardening, linux-hardening, security-competition, nextjs, supabase, python,
realtime, education, capture-the-flag-alternative -->

<div align="center">

### 👤 Developed by **Abil Khosim** — *Cybersecurity Specialist*

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Abil%20Khosim-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/abil-khosim-itsec/)

*BlueForge* is an original project by Abil Khosim, an independent security tool by Abil Khosim (NoxNull). Released under the MIT License —
please keep this attribution when reusing or redistributing.

<sub>Stop collecting flags. Start patching real vulnerabilities. 🛡️</sub>

</div>
