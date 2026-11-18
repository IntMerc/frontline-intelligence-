-- Frontline Intelligence: Supabase PostgreSQL schema
-- Apply in a new Supabase project after reviewing the production security policy.

create extension if not exists pgcrypto;

create type public.review_status as enum ('draft','pending','approved','rejected','archived');
create type public.confidence_level as enum ('high','moderate','low','disputed','illustrative');
create type public.annotation_kind as enum ('context_area','approximate_boundary','public_report','disputed_context','humanitarian_context','historical_reference');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'reader' check (role in ('reader','editor','admin')),
  created_at timestamptz not null default now()
);

create table public.conflicts (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  region text not null,
  conflict_type text,
  summary text not null default '',
  status text not null default 'monitoring',
  public_visible boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.sources (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  publisher text not null,
  url text not null,
  published_at timestamptz,
  accessed_at timestamptz not null default now(),
  source_type text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  conflict_id uuid not null references public.conflicts(id) on delete cascade,
  title text not null,
  summary text not null,
  body text,
  source_id uuid references public.sources(id),
  confidence public.confidence_level not null default 'low',
  status public.review_status not null default 'draft',
  event_date timestamptz,
  published_at timestamptz,
  reviewed_at timestamptz,
  reviewer_id uuid references auth.users(id),
  correction_note text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.annotations (
  id uuid primary key default gen_random_uuid(),
  conflict_id uuid not null references public.conflicts(id) on delete cascade,
  report_id uuid references public.reports(id) on delete set null,
  label text not null,
  description text not null,
  kind public.annotation_kind not null,
  -- GeoJSON geometry in WGS84. Public geometries must be generalized and reviewed.
  geometry jsonb not null,
  precision_label text not null default 'regional',
  confidence public.confidence_level not null default 'low',
  valid_from date,
  valid_to date,
  status public.review_status not null default 'draft',
  created_by uuid references auth.users(id),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.corrections (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references public.reports(id) on delete cascade,
  annotation_id uuid references public.annotations(id) on delete cascade,
  reason text not null,
  correction_text text,
  submitted_by uuid references auth.users(id),
  status public.review_status not null default 'pending',
  reviewed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check (report_id is not null or annotation_id is not null)
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create index reports_conflict_status_date on public.reports(conflict_id,status,event_date desc);
create index annotations_conflict_status on public.annotations(conflict_id,status);
create index sources_published_at on public.sources(published_at desc);

-- Enable RLS on every exposed table.
alter table public.profiles enable row level security;
alter table public.conflicts enable row level security;
alter table public.sources enable row level security;
alter table public.reports enable row level security;
alter table public.annotations enable row level security;
alter table public.corrections enable row level security;
alter table public.audit_log enable row level security;

-- Helper: role checks are based on the authenticated user's profile.
create or replace function public.current_role()
returns text language sql stable security definer set search_path = public
as $$ select coalesce((select role from public.profiles where id = auth.uid()), 'reader') $$;

create policy "profiles read own" on public.profiles for select to authenticated using (id = auth.uid() or public.current_role() in ('editor','admin'));
create policy "public reads visible conflicts" on public.conflicts for select to anon, authenticated using (public_visible = true or public.current_role() in ('editor','admin'));
create policy "editors manage conflicts" on public.conflicts for all to authenticated using (public.current_role() in ('editor','admin')) with check (public.current_role() in ('editor','admin'));
create policy "public reads sources attached to approved reports" on public.sources for select to anon, authenticated using (
  exists(select 1 from public.reports r where r.source_id = sources.id and r.status = 'approved')
  or public.current_role() in ('editor','admin')
);
create policy "editors manage sources" on public.sources for all to authenticated using (public.current_role() in ('editor','admin')) with check (public.current_role() in ('editor','admin'));
create policy "public reads approved reports" on public.reports for select to anon, authenticated using (status = 'approved' or public.current_role() in ('editor','admin'));
create policy "editors manage reports" on public.reports for all to authenticated using (public.current_role() in ('editor','admin')) with check (public.current_role() in ('editor','admin'));
create policy "public reads approved annotations" on public.annotations for select to anon, authenticated using (status = 'approved' or public.current_role() in ('editor','admin'));
create policy "editors manage annotations" on public.annotations for all to authenticated using (public.current_role() in ('editor','admin')) with check (public.current_role() in ('editor','admin'));
create policy "authenticated submit corrections" on public.corrections for insert to authenticated with check (submitted_by = auth.uid());
create policy "submitter reads own corrections" on public.corrections for select to authenticated using (submitted_by = auth.uid() or public.current_role() in ('editor','admin'));
create policy "editors review corrections" on public.corrections for update to authenticated using (public.current_role() in ('editor','admin')) with check (public.current_role() in ('editor','admin'));
create policy "admins read audit" on public.audit_log for select to authenticated using (public.current_role() = 'admin');
create policy "editors write audit" on public.audit_log for insert to authenticated with check (public.current_role() in ('editor','admin'));

-- IMPORTANT: Do not expose service-role keys in a browser. Promote first admin manually
-- from a trusted SQL session after the user account exists:
-- update public.profiles set role='admin' where id='<AUTH_USER_UUID>';
