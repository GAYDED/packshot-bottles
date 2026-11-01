-- Packshot Studio: tables and access rules for personal accounts.
-- Paste the whole file into Supabase → SQL Editor → New query → Run. Safe to run again.

-- Bottle library: one row per saved bottle; the original photo lives in Storage (bucket "bottles").
create table if not exists public.bottles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null,
  name0 text,
  hash text,
  w int,
  h int,
  height_mm numeric,
  base_mm numeric,
  thumb text,
  image_path text,
  ext text,
  created_at timestamptz not null default now()
);

-- Saved settings presets.
create table if not exists public.presets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null,
  settings jsonb not null,
  created_at timestamptz not null default now()
);

-- Per-user prompt history and remembered bottle sizes.
create table if not exists public.user_state (
  user_id uuid primary key default auth.uid() references auth.users on delete cascade,
  history jsonb not null default '[]'::jsonb,
  sizes jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Everyone sees and changes only their own rows.
alter table public.bottles enable row level security;
alter table public.presets enable row level security;
alter table public.user_state enable row level security;

drop policy if exists "own bottles" on public.bottles;
create policy "own bottles" on public.bottles for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own presets" on public.presets;
create policy "own presets" on public.presets for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own state" on public.user_state;
create policy "own state" on public.user_state for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Private bucket for original bottle photos; each user writes only into a folder named after their id.
insert into storage.buckets (id, name, public)
values ('bottles', 'bottles', false)
on conflict (id) do nothing;

drop policy if exists "own bottle files" on storage.objects;
create policy "own bottle files" on storage.objects for all to authenticated
  using (bucket_id = 'bottles' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'bottles' and (storage.foldername(name))[1] = auth.uid()::text);
