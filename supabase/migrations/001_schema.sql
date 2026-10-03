-- Pinoy Creator Map — core schema
-- Places (cities/municipalities) have a fixed number of slots.
-- Creators claim a slot; claims are held until an admin approves (payment step comes later).

create extension if not exists pgcrypto;

-- ───────────────────────── places ─────────────────────────
create table public.places (
  id             text primary key,                       -- slug, e.g. 'cebu-city'
  name           text not null,
  province       text not null,
  region         text not null,
  island_group   text not null check (island_group in ('Luzon','Visayas','Mindanao')),
  kind           text not null check (kind in ('city','municipality')),
  tier           text not null check (tier in ('small','mid','major')),
  lat            double precision not null,
  lng            double precision not null,
  slot_count     int  not null check (slot_count between 1 and 500),
  slot_price_php int  not null check (slot_price_php > 0),
  top_price_php  int  not null check (top_price_php > 0),
  is_open        boolean not null default true,
  psgc_code      text,                                   -- PSA code, filled in later
  created_at     timestamptz not null default now()
);

-- ───────────────────────── creators ─────────────────────────
create table public.creators (
  id             uuid primary key default gen_random_uuid(),
  display_name   text not null check (char_length(display_name) between 2 and 40),
  niche          text not null check (char_length(niche) between 2 and 30),
  barangay       text check (char_length(barangay) <= 60),
  follower_range text not null check (follower_range in ('<1K','1K-10K','10K-100K','100K-1M','1M+')),
  youtube_url    text check (youtube_url  ~ '^https://(www\.|m\.)?youtube\.com/[A-Za-z0-9@_./-]{1,100}$'),
  tiktok_url     text check (tiktok_url   ~ '^https://(www\.)?tiktok\.com/@[A-Za-z0-9_.]{1,40}/?$'),
  facebook_url   text check (facebook_url ~ '^https://(www\.|m\.)?facebook\.com/[A-Za-z0-9_./-]{1,100}$'),
  contact_email  text not null check (contact_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' and char_length(contact_email) <= 120),
  color          text not null default '#E4572E' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  status         text not null default 'pending' check (status in ('pending','approved','rejected')),
  verified       boolean not null default false,
  is_demo        boolean not null default false,
  created_at     timestamptz not null default now()
);

-- ───────────────────────── slots ─────────────────────────
create table public.slots (
  place_id    text not null references public.places(id) on delete cascade,
  slot_index  int  not null check (slot_index >= 0),
  is_top      boolean not null default false,
  status      text not null default 'available' check (status in ('available','held','live')),
  creator_id  uuid references public.creators(id) on delete set null,
  held_until  timestamptz,
  claimed_at  timestamptz,
  primary key (place_id, slot_index)
);
create index slots_creator_idx on public.slots(creator_id);
create index creators_email_idx on public.creators(contact_email);

-- ───────────────────────── security ─────────────────────────
alter table public.places   enable row level security;
alter table public.creators enable row level security;
alter table public.slots    enable row level security;

-- Public can read places and slots (no personal data in these tables).
create policy "places are public" on public.places for select to anon, authenticated using (true);
create policy "slots are public"  on public.slots  for select to anon, authenticated using (true);

-- Public can read APPROVED creators only, and never the contact email (column grants below).
create policy "approved creators are public" on public.creators
  for select to anon, authenticated using (status = 'approved');

revoke all on public.places, public.creators, public.slots from anon, authenticated;
grant select on public.places, public.slots to anon, authenticated;
grant select (id, display_name, niche, barangay, follower_range, youtube_url, tiktok_url,
              facebook_url, color, verified, is_demo, created_at)
  on public.creators to anon, authenticated;
-- No insert/update/delete grants: all writes go through the function below.

-- ───────────────────────── claim flow ─────────────────────────
-- Holds a slot for 24h while the claim is reviewed / paid.
create or replace function public.request_claim(
  p_place_id text, p_slot_index int,
  p_display_name text, p_niche text, p_barangay text, p_follower_range text,
  p_youtube text, p_tiktok text, p_facebook text,
  p_email text, p_color text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_slot   public.slots%rowtype;
  v_place  public.places%rowtype;
  v_id     uuid;
begin
  select * into v_place from public.places where id = p_place_id;
  if not found or not v_place.is_open then
    raise exception 'This place is not open for claims yet';
  end if;

  if num_nonnulls(nullif(trim(p_youtube), ''), nullif(trim(p_tiktok), ''), nullif(trim(p_facebook), '')) = 0 then
    raise exception 'Add at least one channel link';
  end if;

  -- Basic abuse limits
  if (select count(*) from public.creators
        where contact_email = lower(trim(p_email)) and status = 'pending') >= 3 then
    raise exception 'Too many pending claims for this email';
  end if;
  if (select count(*) from public.creators
        where status = 'pending' and created_at > now() - interval '1 hour') >= 200 then
    raise exception 'Claims are busy right now, please try again later';
  end if;

  -- Lock the slot so two people cannot claim it at the same time
  select * into v_slot from public.slots
   where place_id = p_place_id and slot_index = p_slot_index
   for update;
  if not found then
    raise exception 'Slot does not exist';
  end if;
  if v_slot.status = 'live'
     or (v_slot.status = 'held' and v_slot.held_until > now()) then
    raise exception 'Sorry, this slot was just taken';
  end if;

  -- Release a previous expired holder
  if v_slot.status = 'held' and v_slot.creator_id is not null then
    update public.creators set status = 'rejected'
     where id = v_slot.creator_id and status = 'pending';
  end if;

  insert into public.creators (display_name, niche, barangay, follower_range,
                               youtube_url, tiktok_url, facebook_url, contact_email, color)
  values (trim(p_display_name), trim(p_niche), nullif(trim(p_barangay), ''), p_follower_range,
          nullif(trim(p_youtube), ''), nullif(trim(p_tiktok), ''), nullif(trim(p_facebook), ''),
          lower(trim(p_email)), coalesce(nullif(p_color, ''), '#E4572E'))
  returning id into v_id;

  update public.slots
     set status = 'held', creator_id = v_id, held_until = now() + interval '24 hours'
   where place_id = p_place_id and slot_index = p_slot_index;

  return v_id;
end;
$$;

revoke all on function public.request_claim(text,int,text,text,text,text,text,text,text,text,text) from public;
grant execute on function public.request_claim(text,int,text,text,text,text,text,text,text,text,text) to anon, authenticated;

-- ───────────────────────── admin (dashboard / service role only) ─────────────────────────
create or replace function public.approve_creator(p_creator uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.creators set status = 'approved' where id = p_creator;
  update public.slots set status = 'live', held_until = null, claimed_at = now()
   where creator_id = p_creator;
end; $$;

create or replace function public.reject_creator(p_creator uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.creators set status = 'rejected' where id = p_creator;
  update public.slots set status = 'available', creator_id = null, held_until = null
   where creator_id = p_creator;
end; $$;

revoke all on function public.approve_creator(uuid) from public, anon, authenticated;
revoke all on function public.reject_creator(uuid)  from public, anon, authenticated;

-- Pending claims queue for the admin (not exposed to the public API)
create or replace view public.admin_pending_claims
with (security_invoker = true) as
select c.id as creator_id, c.display_name, c.contact_email, c.niche, c.follower_range,
       c.youtube_url, c.tiktok_url, c.facebook_url, s.place_id, s.slot_index, s.is_top,
       s.held_until, c.created_at
  from public.creators c
  join public.slots s on s.creator_id = c.id
 where c.status = 'pending'
 order by c.created_at;
revoke all on public.admin_pending_claims from anon, authenticated;
