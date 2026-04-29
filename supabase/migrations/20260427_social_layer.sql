-- =============================================================================
-- 20260427_social_layer.sql
-- Expenso Social Layer: contact discovery, friend graph, room invites,
-- referral tracking, and a notification-event log shared between local and
-- (future) push delivery.
--
-- Idempotent — safe to run multiple times. Builds on the existing
-- shared_rooms / shared_room_members / user_stats tables.
-- =============================================================================

create extension if not exists pgcrypto;

-- =============================================================================
-- 1. user_profiles  —  hashable identifiers for friend discovery
-- =============================================================================
-- Lives next to user_stats. user_stats owns gamification (coins, xp, streak,
-- referral_code). user_profiles owns "who is this user, and how do contacts
-- on other devices match them".

create table if not exists public.user_profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text,
  avatar_url    text,
  phone_hash    text,                      -- sha256 of E.164-normalized phone
  email_hash    text,                      -- sha256 of lower-cased email
  bio           text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists idx_user_profiles_phone_hash
  on public.user_profiles(phone_hash) where phone_hash is not null;
create index if not exists idx_user_profiles_email_hash
  on public.user_profiles(email_hash) where email_hash is not null;

-- Bootstrap a profile row whenever a new auth.users row is inserted.
create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_profiles (id, display_name, avatar_url, email_hash)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name',
             split_part(coalesce(new.email,''), '@', 1)),
    new.raw_user_meta_data->>'avatar',
    case when new.email is not null and new.email <> ''
         then encode(digest(lower(new.email), 'sha256'), 'hex')
         else null end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
  after insert on auth.users
  for each row execute function public.handle_new_user_profile();

-- Backfill any pre-existing users.
insert into public.user_profiles (id, display_name, email_hash)
select
  u.id,
  coalesce(u.raw_user_meta_data->>'name',
           split_part(coalesce(u.email,''), '@', 1)),
  case when u.email is not null and u.email <> ''
       then encode(digest(lower(u.email), 'sha256'), 'hex')
       else null end
from auth.users u
on conflict (id) do nothing;


-- =============================================================================
-- 2. friendships  —  symmetric, alphabetically-ordered pairs
-- =============================================================================
create table if not exists public.friendships (
  user_a      uuid not null references auth.users(id) on delete cascade,
  user_b      uuid not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);

create index if not exists idx_friendships_user_a on public.friendships(user_a);
create index if not exists idx_friendships_user_b on public.friendships(user_b);


-- =============================================================================
-- 3. friend_requests
-- =============================================================================
do $$ begin
  create type friend_request_status as enum ('pending','accepted','declined','cancelled');
exception when duplicate_object then null; end $$;

create table if not exists public.friend_requests (
  id            uuid primary key default gen_random_uuid(),
  from_user     uuid not null references auth.users(id) on delete cascade,
  to_user       uuid not null references auth.users(id) on delete cascade,
  status        friend_request_status not null default 'pending',
  message       text,
  created_at    timestamptz not null default now(),
  responded_at  timestamptz,
  unique (from_user, to_user),
  check (from_user <> to_user)
);

create index if not exists idx_friend_requests_to_user_status
  on public.friend_requests(to_user, status);
create index if not exists idx_friend_requests_from_user
  on public.friend_requests(from_user);


-- =============================================================================
-- 4. contact_matches  —  one row per phone-contact, owned by a user
-- =============================================================================
create table if not exists public.contact_matches (
  id               uuid primary key default gen_random_uuid(),
  owner            uuid not null references auth.users(id) on delete cascade,
  display_name     text not null,
  phone_hash       text,
  email_hash       text,
  matched_user_id  uuid references auth.users(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- Allow null + unique: dedupe by hash combination per owner.
create unique index if not exists uq_contact_matches_owner_hashes
  on public.contact_matches(owner, coalesce(phone_hash,''), coalesce(email_hash,''));

create index if not exists idx_contact_matches_owner
  on public.contact_matches(owner);
create index if not exists idx_contact_matches_owner_phone
  on public.contact_matches(owner, phone_hash) where phone_hash is not null;
create index if not exists idx_contact_matches_matched_user
  on public.contact_matches(matched_user_id) where matched_user_id is not null;


-- =============================================================================
-- 5. room_invites
-- =============================================================================
do $$ begin
  create type room_invite_status as enum ('pending','accepted','declined','cancelled','expired');
exception when duplicate_object then null; end $$;

create table if not exists public.room_invites (
  id            uuid primary key default gen_random_uuid(),
  room_id       uuid not null references public.shared_rooms(id) on delete cascade,
  from_user     uuid not null references auth.users(id) on delete cascade,
  to_user       uuid not null references auth.users(id) on delete cascade,
  status        room_invite_status not null default 'pending',
  created_at    timestamptz not null default now(),
  responded_at  timestamptz,
  unique (room_id, to_user),
  check (from_user <> to_user)
);

create index if not exists idx_room_invites_to_user_status
  on public.room_invites(to_user, status);
create index if not exists idx_room_invites_room
  on public.room_invites(room_id);


-- =============================================================================
-- 6. referrals  —  outbound invite tracking & conversion
-- =============================================================================
do $$ begin
  create type referral_status as enum ('sent','installed','rewarded');
exception when duplicate_object then null; end $$;

create table if not exists public.referrals (
  id            uuid primary key default gen_random_uuid(),
  referrer_id   uuid not null references auth.users(id) on delete cascade,
  referee_id    uuid references auth.users(id) on delete set null,
  code_used     text not null,
  status        referral_status not null default 'sent',
  channel       text,                       -- 'whatsapp' | 'sms' | 'email' | 'share' | 'other'
  created_at    timestamptz not null default now(),
  installed_at  timestamptz,
  rewarded_at   timestamptz
);

create index if not exists idx_referrals_referrer on public.referrals(referrer_id);
create index if not exists idx_referrals_code     on public.referrals(code_used);


-- =============================================================================
-- 7. notification_events  —  durable log used by local + push delivery
-- =============================================================================
create table if not exists public.notification_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  type        text not null,                -- 'friend_request', 'friend_accepted',
                                            -- 'room_invite', 'room_invite_accepted',
                                            -- 'shared_expense_added', 'settle_owed',
                                            -- 'settlement_received', 'settlement_reminder',
                                            -- 'room_renamed'
  title       text not null,
  body        text,
  payload     jsonb not null default '{}'::jsonb,
  delivered   boolean not null default false,
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);

create index if not exists idx_notif_user_unread
  on public.notification_events(user_id, read_at) where read_at is null;
create index if not exists idx_notif_user_created
  on public.notification_events(user_id, created_at desc);


-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

alter table public.user_profiles      enable row level security;
alter table public.friendships        enable row level security;
alter table public.friend_requests    enable row level security;
alter table public.contact_matches    enable row level security;
alter table public.room_invites       enable row level security;
alter table public.referrals          enable row level security;
alter table public.notification_events enable row level security;

-- ----- user_profiles: world-readable to authenticated (so we can resolve
-- ----- names of friends, members, requesters), self-write only.
drop policy if exists user_profiles_select_all   on public.user_profiles;
create policy user_profiles_select_all
  on public.user_profiles for select to authenticated using (true);

drop policy if exists user_profiles_update_self  on public.user_profiles;
create policy user_profiles_update_self
  on public.user_profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists user_profiles_insert_self  on public.user_profiles;
create policy user_profiles_insert_self
  on public.user_profiles for insert to authenticated
  with check (id = auth.uid());

-- ----- friendships: pair members only.
drop policy if exists friendships_select on public.friendships;
create policy friendships_select
  on public.friendships for select to authenticated
  using (auth.uid() = user_a or auth.uid() = user_b);

drop policy if exists friendships_delete on public.friendships;
create policy friendships_delete
  on public.friendships for delete to authenticated
  using (auth.uid() = user_a or auth.uid() = user_b);

-- (insert is performed only by accept_friend_request RPC under SECURITY DEFINER)

-- ----- friend_requests
drop policy if exists fr_select on public.friend_requests;
create policy fr_select
  on public.friend_requests for select to authenticated
  using (auth.uid() = from_user or auth.uid() = to_user);

drop policy if exists fr_insert on public.friend_requests;
create policy fr_insert
  on public.friend_requests for insert to authenticated
  with check (auth.uid() = from_user);

drop policy if exists fr_update on public.friend_requests;
create policy fr_update
  on public.friend_requests for update to authenticated
  using (auth.uid() = to_user or auth.uid() = from_user)
  with check (auth.uid() = to_user or auth.uid() = from_user);

-- ----- contact_matches: owner-only.
drop policy if exists cm_owner_all on public.contact_matches;
create policy cm_owner_all
  on public.contact_matches for all to authenticated
  using (auth.uid() = owner) with check (auth.uid() = owner);

-- ----- room_invites
drop policy if exists ri_select on public.room_invites;
create policy ri_select
  on public.room_invites for select to authenticated
  using (auth.uid() = from_user or auth.uid() = to_user);

drop policy if exists ri_insert on public.room_invites;
create policy ri_insert
  on public.room_invites for insert to authenticated
  with check (
    auth.uid() = from_user
    and exists (
      select 1 from public.shared_room_members m
      where m.room_id = room_invites.room_id and m.user_id = auth.uid()
    )
  );

drop policy if exists ri_update on public.room_invites;
create policy ri_update
  on public.room_invites for update to authenticated
  using (auth.uid() = to_user or auth.uid() = from_user)
  with check (auth.uid() = to_user or auth.uid() = from_user);

-- ----- referrals
drop policy if exists ref_select on public.referrals;
create policy ref_select
  on public.referrals for select to authenticated
  using (auth.uid() = referrer_id or auth.uid() = referee_id);

drop policy if exists ref_insert on public.referrals;
create policy ref_insert
  on public.referrals for insert to authenticated
  with check (auth.uid() = referrer_id);

-- ----- notification_events: owner-only read & update; insert via SECURITY DEFINER RPCs.
drop policy if exists ne_select on public.notification_events;
create policy ne_select
  on public.notification_events for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists ne_update on public.notification_events;
create policy ne_update
  on public.notification_events for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);


-- =============================================================================
-- RPCs
-- =============================================================================

-- ----- match_contacts_batch
-- Input: jsonb array of { phone_hash, email_hash, name }.
-- Output: only the rows with a hit. Caller already knows the original hashes;
-- we tag each hit with the matching hash so the client can correlate.
create or replace function public.match_contacts_batch(p_hashes jsonb)
returns table(
  matched_phone_hash text,
  matched_email_hash text,
  matched_user_id    uuid,
  display_name       text,
  avatar_url         text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;

  return query
  with input as (
    select
      lower(coalesce(elem->>'phone_hash','')) as ph,
      lower(coalesce(elem->>'email_hash','')) as eh
    from jsonb_array_elements(p_hashes) elem
  )
  select distinct
    case when i.ph <> '' and p.phone_hash = i.ph then i.ph else null end,
    case when i.eh <> '' and p.email_hash = i.eh then i.eh else null end,
    p.id,
    p.display_name,
    p.avatar_url
  from input i
  join public.user_profiles p
    on (i.ph <> '' and p.phone_hash = i.ph)
    or (i.eh <> '' and p.email_hash = i.eh)
  where p.id <> uid;
end;
$$;


-- ----- send_friend_request
-- Idempotent. If a reverse request already exists, auto-accept (mutual interest).
create or replace function public.send_friend_request(p_to uuid, p_message text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  existing_id uuid;
  reverse_id  uuid;
  new_id uuid;
  v_my_name text;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_to = uid then raise exception 'cannot_friend_self'; end if;

  if exists (
    select 1 from public.friendships
    where user_a = least(uid, p_to) and user_b = greatest(uid, p_to)
  ) then
    raise exception 'already_friends';
  end if;

  -- If they already requested us, treat the send as an accept.
  select id into reverse_id
  from public.friend_requests
  where from_user = p_to and to_user = uid and status = 'pending'
  for update;

  if reverse_id is not null then
    perform public.accept_friend_request(reverse_id);
    return reverse_id;
  end if;

  -- Existing outbound request? refresh to pending.
  select id into existing_id
  from public.friend_requests
  where from_user = uid and to_user = p_to
  for update;

  if existing_id is not null then
    update public.friend_requests
       set status = 'pending', message = p_message,
           responded_at = null, created_at = now()
     where id = existing_id;
    new_id := existing_id;
  else
    insert into public.friend_requests (from_user, to_user, message)
    values (uid, p_to, p_message)
    returning id into new_id;
  end if;

  select display_name into v_my_name from public.user_profiles where id = uid;
  insert into public.notification_events (user_id, type, title, body, payload)
  values (
    p_to, 'friend_request',
    'New friend request',
    coalesce(v_my_name,'Someone') || ' wants to connect on Expenso',
    jsonb_build_object('request_id', new_id, 'from_user', uid)
  );

  return new_id;
end;
$$;


-- ----- accept_friend_request
create or replace function public.accept_friend_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  req record;
  v_my_name text;
begin
  if uid is null then raise exception 'not_authenticated'; end if;

  select * into req
  from public.friend_requests
  where id = p_request_id and to_user = uid and status = 'pending'
  for update;

  if not found then raise exception 'request_not_found'; end if;

  update public.friend_requests
     set status = 'accepted', responded_at = now()
   where id = p_request_id;

  insert into public.friendships (user_a, user_b)
  values (least(req.from_user, req.to_user), greatest(req.from_user, req.to_user))
  on conflict do nothing;

  select display_name into v_my_name from public.user_profiles where id = uid;
  insert into public.notification_events (user_id, type, title, body, payload)
  values (
    req.from_user, 'friend_accepted',
    'Friend request accepted',
    coalesce(v_my_name,'A user') || ' is now your Expenso friend',
    jsonb_build_object('request_id', p_request_id, 'friend_id', uid)
  );
end;
$$;


-- ----- decline_friend_request (or cancel, if from_user calls it)
create or replace function public.decline_friend_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  update public.friend_requests
     set status = case when from_user = uid
                       then 'cancelled'::friend_request_status
                       else 'declined'::friend_request_status end,
         responded_at = now()
   where id = p_request_id
     and (to_user = uid or from_user = uid)
     and status = 'pending';
end;
$$;


-- ----- remove_friend
create or replace function public.remove_friend(p_other uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  delete from public.friendships
   where user_a = least(uid, p_other) and user_b = greatest(uid, p_other);
end;
$$;


-- ----- invite_friend_to_room
create or replace function public.invite_friend_to_room(p_room_id uuid, p_to_user uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  inv_id uuid;
  v_room_name text;
  v_inviter_name text;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_to_user = uid then raise exception 'cannot_invite_self'; end if;

  if not exists (
    select 1 from public.shared_room_members
    where room_id = p_room_id and user_id = uid
  ) then
    raise exception 'not_a_member';
  end if;

  if exists (
    select 1 from public.shared_room_members
    where room_id = p_room_id and user_id = p_to_user
  ) then
    raise exception 'already_member';
  end if;

  select id into inv_id from public.room_invites
   where room_id = p_room_id and to_user = p_to_user
   for update;

  if inv_id is not null then
    update public.room_invites
       set status = 'pending', responded_at = null,
           created_at = now(), from_user = uid
     where id = inv_id;
  else
    insert into public.room_invites (room_id, from_user, to_user)
    values (p_room_id, uid, p_to_user)
    returning id into inv_id;
  end if;

  select sr.room_name into v_room_name from public.shared_rooms sr where sr.id = p_room_id;
  select up.display_name into v_inviter_name from public.user_profiles up where up.id = uid;

  insert into public.notification_events (user_id, type, title, body, payload)
  values (
    p_to_user, 'room_invite',
    'Invited to ' || coalesce(v_room_name,'a shared room'),
    coalesce(v_inviter_name,'A friend')
      || ' invited you to a shared expense room',
    jsonb_build_object('invite_id', inv_id, 'room_id', p_room_id, 'from_user', uid)
  );

  return inv_id;
end;
$$;


-- ----- accept_room_invite
create or replace function public.accept_room_invite(p_invite_id uuid, p_display_name text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  inv record;
  v_my_name text;
begin
  if uid is null then raise exception 'not_authenticated'; end if;

  select * into inv from public.room_invites
   where id = p_invite_id and to_user = uid and status = 'pending'
   for update;
  if not found then raise exception 'invite_not_found'; end if;

  insert into public.shared_room_members (room_id, user_id, display_name, role)
  values (inv.room_id, uid,
          coalesce(p_display_name,
                   (select display_name from public.user_profiles where id = uid)),
          'member')
  on conflict do nothing;

  update public.room_invites
     set status = 'accepted', responded_at = now()
   where id = p_invite_id;

  select display_name into v_my_name from public.user_profiles where id = uid;
  insert into public.notification_events (user_id, type, title, body, payload)
  values (
    inv.from_user, 'room_invite_accepted',
    'Invite accepted',
    coalesce(v_my_name,'A user') || ' joined your shared room',
    jsonb_build_object('room_id', inv.room_id, 'user_id', uid)
  );

  return inv.room_id;
end;
$$;


-- ----- decline_room_invite (or cancel)
create or replace function public.decline_room_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  update public.room_invites
     set status = case when from_user = uid
                       then 'cancelled'::room_invite_status
                       else 'declined'::room_invite_status end,
         responded_at = now()
   where id = p_invite_id
     and (to_user = uid or from_user = uid)
     and status = 'pending';
end;
$$;


-- ----- send_settlement_reminder  —  notify every other member of a room
create or replace function public.send_settlement_reminder(p_room_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v_room_name text;
  v_sender_name text;
  cnt int := 0;
  m record;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.shared_room_members where room_id = p_room_id and user_id = uid
  ) then
    raise exception 'not_a_member';
  end if;

  select sr.room_name into v_room_name from public.shared_rooms sr where sr.id = p_room_id;
  select up.display_name into v_sender_name from public.user_profiles up where up.id = uid;

  for m in
    select user_id from public.shared_room_members
    where room_id = p_room_id and user_id <> uid
  loop
    insert into public.notification_events (user_id, type, title, body, payload)
    values (
      m.user_id, 'settlement_reminder',
      'Time to settle up',
      coalesce(v_sender_name,'A member')
        || ' is asking to settle balances in '
        || coalesce(v_room_name,'your shared room'),
      jsonb_build_object('room_id', p_room_id, 'from_user', uid)
    );
    cnt := cnt + 1;
  end loop;

  return cnt;
end;
$$;


-- ----- mark_notification_read
create or replace function public.mark_notification_read(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  update public.notification_events
     set read_at = now()
   where id = p_id and user_id = uid;
end;
$$;


-- ----- mark_all_notifications_read
create or replace function public.mark_all_notifications_read()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  update public.notification_events
     set read_at = now()
   where user_id = uid and read_at is null;
end;
$$;


-- ----- update_my_profile_hashes  —  client pushes hashes after onboarding
create or replace function public.update_my_profile_hashes(
  p_phone_hash text default null,
  p_email_hash text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  update public.user_profiles
     set phone_hash = coalesce(nullif(p_phone_hash,''), phone_hash),
         email_hash = coalesce(nullif(p_email_hash,''), email_hash),
         updated_at = now()
   where id = uid;
end;
$$;


-- ----- record_referral
create or replace function public.record_referral(p_code text, p_channel text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  new_id uuid;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  insert into public.referrals (referrer_id, code_used, channel)
  values (uid, p_code, p_channel)
  returning id into new_id;
  return new_id;
end;
$$;


-- ----- emit_notification  —  helper to enqueue an event for an explicit user.
-- Useful for shared-expense triggers added later. Caller must own the source
-- (e.g. the expense), but we don't enforce that here — call only via DEFINER paths.
create or replace function public.emit_notification(
  p_user_id uuid,
  p_type    text,
  p_title   text,
  p_body    text default null,
  p_payload jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
begin
  insert into public.notification_events (user_id, type, title, body, payload)
  values (p_user_id, p_type, p_title, p_body, p_payload)
  returning id into new_id;
  return new_id;
end;
$$;


-- =============================================================================
-- GRANTS
-- =============================================================================
grant execute on function public.match_contacts_batch(jsonb)               to authenticated;
grant execute on function public.send_friend_request(uuid, text)           to authenticated;
grant execute on function public.accept_friend_request(uuid)               to authenticated;
grant execute on function public.decline_friend_request(uuid)              to authenticated;
grant execute on function public.remove_friend(uuid)                       to authenticated;
grant execute on function public.invite_friend_to_room(uuid, uuid)         to authenticated;
grant execute on function public.accept_room_invite(uuid, text)            to authenticated;
grant execute on function public.decline_room_invite(uuid)                 to authenticated;
grant execute on function public.send_settlement_reminder(uuid)            to authenticated;
grant execute on function public.mark_notification_read(uuid)              to authenticated;
grant execute on function public.mark_all_notifications_read()             to authenticated;
grant execute on function public.update_my_profile_hashes(text, text)      to authenticated;
grant execute on function public.record_referral(text, text)               to authenticated;
-- emit_notification deliberately not granted; only callable via SECURITY DEFINER chains.

-- =============================================================================
-- AUTOMATED EVENT TRIGGERS
-- =============================================================================

-- Fan-out a notification when a shared expense is added so all *other* members
-- get a "new shared expense" event.
create or replace function public.on_shared_expense_inserted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room_name text;
  v_payer_name text;
  m record;
begin
  select sr.room_name into v_room_name
    from public.shared_rooms sr where sr.id = new.room_id;
  select up.display_name into v_payer_name
    from public.user_profiles up where up.id = new.paid_by;

  for m in
    select user_id from public.shared_room_members
     where room_id = new.room_id and user_id <> new.paid_by
  loop
    insert into public.notification_events (user_id, type, title, body, payload)
    values (
      m.user_id, 'shared_expense_added',
      coalesce(v_payer_name,'A member')
        || ' added an expense in '
        || coalesce(v_room_name,'your shared room'),
      new.title || ' — ' || to_char(new.amount, 'FM999G999G990D00'),
      jsonb_build_object(
        'room_id', new.room_id,
        'expense_id', new.id,
        'paid_by', new.paid_by,
        'amount', new.amount
      )
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists trg_shared_expense_notify on public.shared_expenses;
create trigger trg_shared_expense_notify
  after insert on public.shared_expenses
  for each row execute function public.on_shared_expense_inserted();


-- Notify recipient when a settlement is recorded.
create or replace function public.on_shared_settlement_inserted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room_name text;
  v_sender_name text;
begin
  select sr.room_name into v_room_name
    from public.shared_rooms sr where sr.id = new.room_id;
  select up.display_name into v_sender_name
    from public.user_profiles up where up.id = new.from_user;

  insert into public.notification_events (user_id, type, title, body, payload)
  values (
    new.to_user, 'settlement_received',
    'Payment received',
    coalesce(v_sender_name,'Someone')
      || ' paid you '
      || to_char(new.amount, 'FM999G999G990D00')
      || ' in '
      || coalesce(v_room_name,'a shared room'),
    jsonb_build_object(
      'room_id', new.room_id,
      'settlement_id', new.id,
      'from_user', new.from_user,
      'amount', new.amount
    )
  );
  return new;
end;
$$;

drop trigger if exists trg_shared_settlement_notify on public.shared_settlements;
create trigger trg_shared_settlement_notify
  after insert on public.shared_settlements
  for each row execute function public.on_shared_settlement_inserted();


-- Notify all *other* members on rename.
create or replace function public.on_shared_room_renamed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  m record;
begin
  if new.room_name is distinct from old.room_name then
    for m in
      select user_id from public.shared_room_members
       where room_id = new.id and user_id <> auth.uid()
    loop
      insert into public.notification_events (user_id, type, title, body, payload)
      values (
        m.user_id, 'room_renamed',
        'Room renamed',
        'A shared room was renamed to "' || new.room_name || '"',
        jsonb_build_object('room_id', new.id, 'old_name', old.room_name, 'new_name', new.room_name)
      );
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_shared_room_renamed on public.shared_rooms;
create trigger trg_shared_room_renamed
  after update on public.shared_rooms
  for each row execute function public.on_shared_room_renamed();
