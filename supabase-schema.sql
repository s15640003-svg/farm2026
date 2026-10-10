-- Smart farm secure traceability schema; safe to re-run.
create table if not exists public.farm_logs (
  id text primary key, crop text not null default '', registrar text not null default '',
  group_type text not null default '', category text not null default '', material_name text not null default '',
  hours numeric not null default 1, amount text not null default '1', unit text not null default '',
  dilution text not null default '-', phi text not null default '-', notes text not null default '',
  log_timestamp text not null default '', is_public boolean not null default false,
  photo_urls jsonb not null default '[]'::jsonb, user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.farm_logs add column if not exists is_public boolean not null default false;
alter table public.farm_logs add column if not exists photo_urls jsonb not null default '[]'::jsonb;
alter table public.farm_logs add column if not exists user_id uuid references auth.users(id) on delete set null;
create table if not exists public.farm_tasks (
  id text primary key, title text not null, task_date date not null,
  priority text not null default 'MED', created_at timestamptz not null default now()
);
alter table public.farm_logs enable row level security;
alter table public.farm_tasks enable row level security;
drop policy if exists "Public can read farm logs" on public.farm_logs;
drop policy if exists "Public can insert farm logs" on public.farm_logs;
drop policy if exists "Public can update farm logs" on public.farm_logs;
drop policy if exists "Public can delete farm logs" on public.farm_logs;
drop policy if exists "Anonymous can read published logs" on public.farm_logs;
drop policy if exists "Editors can read all logs" on public.farm_logs;
drop policy if exists "Editors can insert logs" on public.farm_logs;
drop policy if exists "Editors can update logs" on public.farm_logs;
drop policy if exists "Editors can delete logs" on public.farm_logs;
create policy "Anonymous can read published logs" on public.farm_logs for select to anon using (is_public = true);
create policy "Editors can read all logs" on public.farm_logs for select to authenticated using (auth.uid() is not null);
create policy "Editors can insert logs" on public.farm_logs for insert to authenticated with check (auth.uid() is not null and (user_id is null or user_id = auth.uid()));
create policy "Editors can update logs" on public.farm_logs for update to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
create policy "Editors can delete logs" on public.farm_logs for delete to authenticated using (auth.uid() is not null);
drop policy if exists "Public can read farm tasks" on public.farm_tasks;
drop policy if exists "Public can insert farm tasks" on public.farm_tasks;
drop policy if exists "Public can update farm tasks" on public.farm_tasks;
drop policy if exists "Public can delete farm tasks" on public.farm_tasks;
drop policy if exists "Editors can read farm tasks" on public.farm_tasks;
drop policy if exists "Editors can insert farm tasks" on public.farm_tasks;
drop policy if exists "Editors can update farm tasks" on public.farm_tasks;
drop policy if exists "Editors can delete farm tasks" on public.farm_tasks;
create policy "Editors can read farm tasks" on public.farm_tasks for select to authenticated using (auth.uid() is not null);
create policy "Editors can insert farm tasks" on public.farm_tasks for insert to authenticated with check (auth.uid() is not null);
create policy "Editors can update farm tasks" on public.farm_tasks for update to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
create policy "Editors can delete farm tasks" on public.farm_tasks for delete to authenticated using (auth.uid() is not null);
grant select on public.farm_logs to anon;
grant select, insert, update, delete on public.farm_logs to authenticated;
grant select, insert, update, delete on public.farm_tasks to authenticated;
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('farm-public-photos','farm-public-photos',true,8388608,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true,file_size_limit=8388608,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('farm-private-photos','farm-private-photos',false,8388608,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false,file_size_limit=8388608,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists "Public can read published farm photos" on storage.objects;
drop policy if exists "Editors can read private farm photos" on storage.objects;
drop policy if exists "Editors can upload farm photos" on storage.objects;
drop policy if exists "Editors can update farm photos" on storage.objects;
drop policy if exists "Editors can delete farm photos" on storage.objects;
create policy "Public can read published farm photos" on storage.objects for select to anon, authenticated using (bucket_id='farm-public-photos');
create policy "Editors can read private farm photos" on storage.objects for select to authenticated using (bucket_id='farm-private-photos');
create policy "Editors can upload farm photos" on storage.objects for insert to authenticated with check (bucket_id in ('farm-public-photos','farm-private-photos') and (storage.foldername(name))[1]=auth.uid()::text);
create policy "Editors can update farm photos" on storage.objects for update to authenticated using (bucket_id in ('farm-public-photos','farm-private-photos') and auth.uid() is not null) with check (bucket_id in ('farm-public-photos','farm-private-photos') and auth.uid() is not null);
create policy "Editors can delete farm photos" on storage.objects for delete to authenticated using (bucket_id in ('farm-public-photos','farm-private-photos') and auth.uid() is not null);
do $$ begin alter publication supabase_realtime add table public.farm_logs; exception when duplicate_object then null; when others then if sqlstate <> '42710' then raise; end if; end $$;
do $$ begin alter publication supabase_realtime add table public.farm_tasks; exception when duplicate_object then null; when others then if sqlstate <> '42710' then raise; end if; end $$;
