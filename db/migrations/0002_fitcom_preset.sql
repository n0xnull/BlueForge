-- =====================================================================
-- Migration 0002 — Preset "fitcom" (v0.4, 30 celah)
-- Additive-only policy (TDD §27): migration ini hanya MENAMBAH nilai yang
-- diizinkan di constraint `difficulties.key`, tidak mengubah/menghapus
-- kolom atau baris manapun.
--
-- Jalankan di database yang SUDAH punya schema v0.1 (db/schema.sql) --
-- misalnya lewat Supabase SQL Editor / psql. Aman dijalankan berkali-kali.
--
-- Setelah migration ini: jalankan ulang db/seed/difficulties.sql (v0.4) --
-- itu yang benar-benar mengisi 15 check baru + preset "fitcom".
-- =====================================================================

-- Cari & buang CHECK constraint lama pada kolom `difficulties.key` APAPUN
-- namanya (bukan asumsi nama default Postgres "difficulties_key_check" --
-- lebih aman kalau constraint pernah dibuat/di-rename manual sebelumnya),
-- lalu buat ulang dengan 'fitcom' ditambahkan ke daftar yang diizinkan.
do $$
declare
  conname text;
begin
  select con.conname into conname
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_attribute att on att.attrelid = rel.oid and att.attnum = any(con.conkey)
  where rel.relname = 'difficulties' and con.contype = 'c' and att.attname = 'key';

  if conname is not null then
    execute format('alter table difficulties drop constraint %I', conname);
  end if;
end $$;

alter table difficulties add constraint difficulties_key_check
  check (key in ('easy','medium','hard','fitcom'));
