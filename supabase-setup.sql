-- =====================================================================
-- RIYAN STUDIO — Supabase setup (run ONCE in: Supabase Dashboard -> SQL Editor -> New query)
-- Safe to re-run: it uses "if not exists" / "drop ... if exists".
-- Matches index.html exactly (table, columns, bucket names, rpc name).
-- Never paste your service_role key anywhere. This script needs no keys.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) ADMIN ALLOWLIST
--    Only users listed here can change the portfolio.
--    Nobody can add themselves: there is NO insert/update/delete policy,
--    so the frontend (anon/authenticated roles) can never write to it.
--    You add yourself manually in the SQL Editor (step 6 below).
-- ---------------------------------------------------------------------
create table if not exists public.admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  email      text,
  created_at timestamptz not null default now()
);

alter table public.admins enable row level security;

-- A logged-in user may only see their OWN row (lets the admin page check "am I an admin?").
-- This policy deliberately does NOT call is_admin(), so there is no circular check.
drop policy if exists "admins: read own row" on public.admins;
create policy "admins: read own row"
  on public.admins for select
  to authenticated
  using (user_id = auth.uid());

-- Helper used by every other policy. SECURITY DEFINER so it can read the
-- admins table regardless of the caller's own RLS.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- ---------------------------------------------------------------------
-- 2) PROJECTS TABLE
-- ---------------------------------------------------------------------
create table if not exists public.projects (
  id            uuid primary key default gen_random_uuid(),
  title         text not null check (char_length(title) between 1 and 120),
  category      text not null default 'Other' check (char_length(category) between 1 and 60),
  description   text check (char_length(description) <= 600),
  format_label  text check (char_length(format_label) <= 40),
  -- video: 'upload' = file in the portfolio-videos bucket (video_path);
  --        'youtube' | 'vimeo' | 'direct' = external link (video_url)
  video_type    text not null check (video_type in ('upload','youtube','vimeo','direct')),
  video_url     text,
  video_path    text,
  -- thumbnail: either an uploaded file (thumbnail_path) or an image link (thumbnail_url); both null = placeholder
  thumbnail_url  text,
  thumbnail_path text,
  aspect_ratio  text not null default '16:9' check (aspect_ratio in ('16:9','9:16','1:1')),
  external_link text,
  featured      boolean not null default false,
  published     boolean not null default true,
  display_order integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint projects_video_source_ok check (
    (video_type = 'upload' and video_path is not null)
    or (video_type <> 'upload' and video_url is not null)
  )
);

create index if not exists projects_order_idx     on public.projects (display_order, created_at);
create index if not exists projects_published_idx on public.projects (published, display_order);

-- keep updated_at fresh
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists projects_set_updated_at on public.projects;
create trigger projects_set_updated_at
  before update on public.projects
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 3) ROW LEVEL SECURITY FOR PROJECTS  (RLS stays ON — never disable it)
-- ---------------------------------------------------------------------
alter table public.projects enable row level security;

-- Table privileges (RLS below still decides which rows)
grant select on public.projects to anon, authenticated;
grant insert, update, delete on public.projects to authenticated;
grant select on public.admins to authenticated;

drop policy if exists "projects: public read published" on public.projects;
create policy "projects: public read published"
  on public.projects for select
  to anon, authenticated
  using (published = true or public.is_admin());

drop policy if exists "projects: admin insert" on public.projects;
create policy "projects: admin insert"
  on public.projects for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists "projects: admin update" on public.projects;
create policy "projects: admin update"
  on public.projects for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "projects: admin delete" on public.projects;
create policy "projects: admin delete"
  on public.projects for delete
  to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------
-- 4) ATOMIC REORDER (used by the up/down arrows in the admin page)
--    SECURITY INVOKER: it runs with the caller's rights, so the update
--    policy above applies. The explicit check gives a clear error.
-- ---------------------------------------------------------------------
create or replace function public.reorder_projects(ids uuid[])
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;
  update public.projects p
     set display_order = x.pos
    from (select t.id, (t.ord - 1)::int as pos
            from unnest(ids) with ordinality as t(id, ord)) x
   where p.id = x.id;
end;
$$;

revoke all on function public.reorder_projects(uuid[]) from public;
grant execute on function public.reorder_projects(uuid[]) to authenticated;

-- ---------------------------------------------------------------------
-- 5) STORAGE BUCKETS + POLICIES
--    Buckets are PUBLIC for reading (visitors need to play videos), but only
--    an admin can upload / replace / delete. Public buckets serve files by URL
--    without any SELECT policy, so visitors cannot LIST your files.
--    Video limit: 45 MB per file (Supabase Free allows up to 50 MB).
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('portfolio-videos',     'portfolio-videos',     true, 47185920, array['video/mp4','video/webm']),
  ('portfolio-thumbnails', 'portfolio-thumbnails', true,  5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "portfolio media: admin select" on storage.objects;
create policy "portfolio media: admin select"
  on storage.objects for select
  to authenticated
  using (bucket_id in ('portfolio-videos','portfolio-thumbnails') and public.is_admin());

drop policy if exists "portfolio media: admin insert" on storage.objects;
create policy "portfolio media: admin insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id in ('portfolio-videos','portfolio-thumbnails') and public.is_admin());

drop policy if exists "portfolio media: admin update" on storage.objects;
create policy "portfolio media: admin update"
  on storage.objects for update
  to authenticated
  using (bucket_id in ('portfolio-videos','portfolio-thumbnails') and public.is_admin())
  with check (bucket_id in ('portfolio-videos','portfolio-thumbnails') and public.is_admin());

drop policy if exists "portfolio media: admin delete" on storage.objects;
create policy "portfolio media: admin delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id in ('portfolio-videos','portfolio-thumbnails') and public.is_admin());

-- ---------------------------------------------------------------------
-- 6) AUTHORISE YOUR ADMIN ACCOUNT  (do this AFTER creating your user)
--    a) Dashboard -> Authentication -> Users -> "Add user" -> "Create new user"
--       enter your email + a strong password, tick "Auto Confirm User".
--    b) Replace the email below with yours and run ONLY this statement:
-- ---------------------------------------------------------------------
-- insert into public.admins (user_id, email)
-- select id, email from auth.users where email = 'YOUR_EMAIL@example.com';

-- ---------------------------------------------------------------------
-- 7) QUICK CHECKS (optional)
-- ---------------------------------------------------------------------
-- select * from public.admins;                       -- should list you after step 6
-- select id, public, file_size_limit from storage.buckets where id like 'portfolio-%';
-- select tablename, rowsecurity from pg_tables where schemaname='public' and tablename in ('admins','projects'); -- both true
