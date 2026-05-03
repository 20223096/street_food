-- Phase 0: Street Food Truck MVP — run in Supabase SQL Editor
-- (gen_random_uuid: built-in on Supabase Postgres; enable pgcrypto if needed)

-- ---------------------------------------------------------------------------
-- trucks
-- ---------------------------------------------------------------------------
create table public.trucks (
  id uuid primary key default gen_random_uuid (),
  name text not null,
  latitude double precision not null,
  longitude double precision not null,
  source text not null
    check (
      source in ('admin_manual', 'user_report', 'insta_auto')
    ),
  category_tags text[] not null default '{}',
  is_active boolean not null default true,
  cover_image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index trucks_location_idx on public.trucks (latitude, longitude);
create index trucks_source_idx on public.trucks (source);
create index trucks_is_active_idx on public.trucks (is_active);

-- reviews
-- ---------------------------------------------------------------------------
create table public.reviews (
  id uuid primary key default gen_random_uuid (),
  truck_id uuid not null references public.trucks (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  content text not null default '',
  created_at timestamptz not null default now ()
);

create index reviews_truck_id_idx on public.reviews (truck_id);
create index reviews_user_id_idx on public.reviews (user_id);

-- updated_at trigger (trucks)
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at ()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trucks_set_updated_at
before update on public.trucks
for each row
execute function public.set_updated_at ();

-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.trucks enable row level security;
alter table public.reviews enable row level security;

-- trucks: anyone can read active trucks (tune for privacy later)
create policy "trucks_select_public"
on public.trucks
for select
using (true);

-- authenticated users may insert user-reported trucks only
create policy "trucks_insert_user_report"
on public.trucks
for insert
to authenticated
with check (source = 'user_report');

-- Storage: truck photos (run after creating bucket in Dashboard or via SQL below)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('truck-photos', 'truck-photos', true)
on conflict (id) do nothing;

create policy "truck_photos_public_read"
on storage.objects
for select
using (bucket_id = 'truck-photos');

create policy "truck_photos_authenticated_upload"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'truck-photos');

create policy "truck_photos_owner_update"
on storage.objects
for update
to authenticated
using (bucket_id = 'truck-photos');

create policy "truck_photos_owner_delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'truck-photos');

-- reviews: read all; write only own rows when authenticated
create policy "reviews_select_public"
on public.reviews
for select
using (true);

create policy "reviews_insert_own"
on public.reviews
for insert
to authenticated
with check (auth.uid () = user_id);

create policy "reviews_update_own"
on public.reviews
for update
to authenticated
using (auth.uid () = user_id);

create policy "reviews_delete_own"
on public.reviews
for delete
to authenticated
using (auth.uid () = user_id);
