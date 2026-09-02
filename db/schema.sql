-- =====================================================================
-- BlueForge — Database Schema (v0.1)
-- Postgres / Supabase. Lihat TDD §20 & §33 (ERD).
-- Aturan: perubahan ke depan via db/migrations/ (additive-only).
-- =====================================================================

create extension if not exists "pgcrypto";   -- gen_random_uuid()

-- ------------------------------------------------------------------
-- DIFFICULTIES (preset tingkat kesulitan: easy | medium | hard)
-- ------------------------------------------------------------------
create table if not exists difficulties (
  id                   uuid primary key default gen_random_uuid(),
  key                  text unique not null check (key in ('easy','medium','hard','fitcom')),
  name                 text not null,
  description          text,
  active_check_codes   jsonb not null default '[]',   -- subset check yang dinilai
  hint_policy          text not null default 'full' check (hint_policy in ('full','limited','none')),
  penalty_weight       numeric not null default 1.0,
  default_duration_sec integer not null default 5400,
  schema_version       text not null default '1.0',
  created_at           timestamptz not null default now()
);

-- ------------------------------------------------------------------
-- CHECKS (definisi celah; code stabil & immutable — TDD §15/§27)
-- ------------------------------------------------------------------
create table if not exists checks (
  id                uuid primary key default gen_random_uuid(),
  code              text unique not null,           -- IMMUTABLE
  title             text not null,
  description       text,
  points            integer not null default 10,
  is_penalty        boolean not null default false,
  must_stay_passing boolean not null default false, -- check ketersediaan layanan
  category          text,
  hint_basic        text,
  hint_advanced     text,
  difficulty_tags   jsonb not null default '[]',    -- ["easy","medium","hard"]
  schema_version    text not null default '1.0',
  created_at        timestamptz not null default now()
);

-- ------------------------------------------------------------------
-- COMPETITIONS (sesi lomba — state machine TDD §18)
-- ------------------------------------------------------------------
create table if not exists competitions (
  id                       uuid primary key default gen_random_uuid(),
  name                     text not null,
  difficulty               text not null references difficulties(key),
  status                   text not null default 'draft'
                             check (status in ('draft','waiting','running','paused','ended','archived')),
  duration_sec             integer not null default 5400,
  started_at               timestamptz,
  ends_at                  timestamptz,
  paused_ms_total          bigint not null default 0,
  session_code             text unique not null,
  image_version            text default '2024.04',
  canonical_baseline_hash  text,
  hint_policy              text not null default 'full',
  penalty_weight           numeric not null default 1.0,
  created_at               timestamptz not null default now()
);

-- ------------------------------------------------------------------
-- PARTICIPANTS (1 peserta = 1 VM)
-- ------------------------------------------------------------------
create table if not exists participants (
  id                uuid primary key default gen_random_uuid(),
  competition_id    uuid not null references competitions(id) on delete cascade,
  full_name         text not null,
  school            text,
  agent_token_hash  text not null,        -- sha256(token)
  agent_secret_hash text not null,        -- sha256(secret) — utk verifikasi HMAC tersimpan terpisah
  status            text not null default 'registered'
                      check (status in ('registered','online','offline','disqualified')),
  agent_version     text,
  last_heartbeat    timestamptz,
  created_at        timestamptz not null default now(),
  unique (competition_id, full_name, school)
);

-- ------------------------------------------------------------------
-- PARTICIPANT_CHECKS (status check terkini per peserta)
-- ------------------------------------------------------------------
create table if not exists participant_checks (
  id             uuid primary key default gen_random_uuid(),
  participant_id uuid not null references participants(id) on delete cascade,
  check_code     text not null,
  passed         boolean not null default false,
  eligible       boolean not null default true,   -- false bila sudah lulus saat START (anti pre-fix)
  scored_points  integer not null default 0,
  updated_at     timestamptz not null default now(),
  unique (participant_id, check_code)
);

-- ------------------------------------------------------------------
-- SCORES (riwayat skor — sumber realtime leaderboard)
-- ------------------------------------------------------------------
create table if not exists scores (
  id             uuid primary key default gen_random_uuid(),
  participant_id uuid not null references participants(id) on delete cascade,
  total_score    integer not null default 0,
  computed_at_ms bigint not null,
  snapshot_at    timestamptz not null default now(),
  unique (participant_id, computed_at_ms)         -- idempotensi (TDD §17)
);

-- ------------------------------------------------------------------
-- SNAPSHOTS (evidence — append-only, TDD §13)
-- ------------------------------------------------------------------
create table if not exists snapshots (
  id             uuid primary key default gen_random_uuid(),
  participant_id uuid not null references participants(id) on delete cascade,
  phase          text not null check (phase in ('registration','start','stop','periodic')),
  taken_at       timestamptz not null default now(),
  server_time_ms bigint,
  checks_state   jsonb not null default '[]',
  artifacts      jsonb not null default '{}',
  baseline_diff  jsonb not null default '{}',
  signature      text
);

-- ------------------------------------------------------------------
-- NONCES (anti-replay, opsional v0.1 — disiapkan utk produksi)
-- ------------------------------------------------------------------
create table if not exists nonces (
  participant_id uuid not null references participants(id) on delete cascade,
  nonce          text not null,
  seen_at        timestamptz not null default now(),
  primary key (participant_id, nonce)
);

-- ------------------------------------------------------------------
-- EVENT_LOGS (audit/anomaly/forensik, TDD §21)
-- ------------------------------------------------------------------
create table if not exists event_logs (
  id             uuid primary key default gen_random_uuid(),
  participant_id uuid references participants(id) on delete set null,
  competition_id uuid references competitions(id) on delete cascade,
  type           text not null,
  level          text not null default 'INFO'
                   check (level in ('INFO','WARN','ERROR','AUDIT','SECURITY')),
  payload        jsonb not null default '{}',
  created_at     timestamptz not null default now()
);

-- ------------------------------------------------------------------
-- VIEW: leaderboard (di-subscribe Realtime — bukan tabel mentah, TDD §27)
-- skor terkini tiap peserta + ranking
-- ------------------------------------------------------------------
create or replace view leaderboard as
select
  p.id                 as participant_id,
  p.competition_id,
  p.full_name,
  p.school,
  p.status,
  coalesce(s.total_score, 0) as total_score,
  s.computed_at_ms,
  rank() over (
    partition by p.competition_id
    order by coalesce(s.total_score,0) desc, s.computed_at_ms asc
  ) as rank
from participants p
left join lateral (
  select total_score, computed_at_ms
  from scores
  where participant_id = p.id
  order by computed_at_ms desc
  limit 1
) s on true;

-- Indeks bantu
create index if not exists idx_scores_participant on scores(participant_id, computed_at_ms desc);
create index if not exists idx_participants_comp on participants(competition_id);
create index if not exists idx_pchecks_participant on participant_checks(participant_id);
create index if not exists idx_events_comp on event_logs(competition_id, created_at desc);
