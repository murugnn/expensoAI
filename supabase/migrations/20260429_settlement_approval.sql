-- ============================================================================
-- Two-step settlement approval flow.
--
-- Before: anyone in a room could insert a row into shared_settlements with
-- status='completed' and immediately reduce balances. The creditor (the
-- person actually owed the money) had no say.
--
-- After: a settlement begins life as 'pending' when proposed by the debtor
-- (or any non-creditor party). Only the creditor (to_user) can transition
-- it to 'completed' or 'cancelled'. Pending and cancelled rows do not move
-- balance math (clients enforce this in computeBalances; the schema just
-- stores status accurately).
--
-- Backward compatibility: existing rows already at status='completed'
-- stay completed — only the *default* changes.
-- ============================================================================

-- 1. Schema additions ---------------------------------------------------------

alter table public.shared_settlements
  alter column status set default 'pending';

alter table public.shared_settlements
  add column if not exists requested_by uuid,
  add column if not exists decided_at   timestamptz,
  add column if not exists decision_note text;

-- Helpful for "what's pending for me" queries.
create index if not exists idx_shared_settlements_to_status
  on public.shared_settlements(to_user, status)
  where status = 'pending';


-- 2. Row-level security -------------------------------------------------------
-- Enable RLS if not already on; idempotent.
alter table public.shared_settlements enable row level security;

-- Drop & recreate so this migration is re-runnable.
drop policy if exists ss_select on public.shared_settlements;
drop policy if exists ss_insert on public.shared_settlements;
drop policy if exists ss_update on public.shared_settlements;
drop policy if exists ss_delete on public.shared_settlements;

-- SELECT: a member of the relevant room can read settlements; in particular
-- both the debtor (from_user) and creditor (to_user) need to see them.
create policy ss_select
  on public.shared_settlements for select to authenticated
  using (
    exists (
      select 1 from public.shared_room_members m
       where m.room_id = shared_settlements.room_id
         and m.user_id = auth.uid()
    )
  );

-- INSERT: anyone who is a member of the room may propose a settlement, but
-- only between two members of that room.
create policy ss_insert
  on public.shared_settlements for insert to authenticated
  with check (
    exists (
      select 1 from public.shared_room_members m
       where m.room_id = shared_settlements.room_id
         and m.user_id = auth.uid()
    )
    and exists (
      select 1 from public.shared_room_members m2
       where m2.room_id = shared_settlements.room_id
         and m2.user_id = shared_settlements.from_user
    )
    and exists (
      select 1 from public.shared_room_members m3
       where m3.room_id = shared_settlements.room_id
         and m3.user_id = shared_settlements.to_user
    )
  );

-- UPDATE: the creditor controls the lifecycle. The debtor may also update
-- their *own* row while it is still pending (e.g. amend the note before
-- the creditor responds), but cannot move it out of 'pending'.
create policy ss_update
  on public.shared_settlements for update to authenticated
  using (
    auth.uid() = to_user
    or (auth.uid() = from_user and status = 'pending')
  )
  with check (
    -- Creditor can transition to anything.
    auth.uid() = to_user
    -- Debtor edits must keep status pending.
    or (auth.uid() = from_user and status = 'pending')
  );

-- DELETE: only the creditor or the debtor on a still-pending row.
create policy ss_delete
  on public.shared_settlements for delete to authenticated
  using (
    auth.uid() = to_user
    or (auth.uid() = from_user and status = 'pending')
  );


-- 3. Replace the insert-trigger that crafted the "Payment received" event.
-- The old trigger fired on every insert and called the event "Payment
-- received" — which is misleading when the row is only 'pending'. Make it
-- type-aware: pending rows produce a "marked as paid" review event for the
-- creditor; completed rows keep the original "payment received" message.
create or replace function public.on_shared_settlement_inserted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room_name   text;
  v_sender_name text;
begin
  select sr.room_name into v_room_name
    from public.shared_rooms sr where sr.id = new.room_id;
  select up.display_name into v_sender_name
    from public.user_profiles up where up.id = new.from_user;

  if new.status = 'pending' then
    insert into public.notification_events (user_id, type, title, body, payload)
    values (
      new.to_user, 'settlement_pending',
      'Payment to review',
      coalesce(v_sender_name,'Someone')
        || ' marked '
        || to_char(new.amount, 'FM999G999G990D00')
        || ' as paid — tap to confirm or dispute',
      jsonb_build_object(
        'room_id', new.room_id,
        'settlement_id', new.id,
        'from_user', new.from_user,
        'amount', new.amount
      )
    );
  elsif new.status = 'completed' then
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
  end if;
  return new;
end;
$$;

drop trigger if exists trg_shared_settlement_notify on public.shared_settlements;
create trigger trg_shared_settlement_notify
  after insert on public.shared_settlements
  for each row execute function public.on_shared_settlement_inserted();


-- 4. New trigger: notify the debtor when the creditor approves or rejects.
create or replace function public.on_shared_settlement_decided()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room_name      text;
  v_creditor_name  text;
  v_amount_text    text;
begin
  -- Only react to the pending → completed/cancelled transition.
  if old.status is not distinct from new.status then
    return new;
  end if;
  if old.status <> 'pending' then
    return new;
  end if;

  select sr.room_name into v_room_name
    from public.shared_rooms sr where sr.id = new.room_id;
  select up.display_name into v_creditor_name
    from public.user_profiles up where up.id = new.to_user;

  v_amount_text := to_char(new.amount, 'FM999G999G990D00');

  if new.status = 'completed' then
    insert into public.notification_events (user_id, type, title, body, payload)
    values (
      new.from_user, 'settlement_approved',
      'Payment confirmed',
      coalesce(v_creditor_name,'Someone')
        || ' confirmed your payment of '
        || v_amount_text
        || coalesce(' in ' || v_room_name, ''),
      jsonb_build_object(
        'room_id', new.room_id,
        'settlement_id', new.id,
        'to_user', new.to_user,
        'amount', new.amount
      )
    );
  elsif new.status = 'cancelled' then
    insert into public.notification_events (user_id, type, title, body, payload)
    values (
      new.from_user, 'settlement_rejected',
      'Payment disputed',
      coalesce(v_creditor_name,'Someone')
        || ' disputed your payment of '
        || v_amount_text
        || case
             when new.decision_note is not null and length(new.decision_note) > 0
               then ' — reason: ' || new.decision_note
             else ''
           end,
      jsonb_build_object(
        'room_id', new.room_id,
        'settlement_id', new.id,
        'to_user', new.to_user,
        'amount', new.amount,
        'reason', new.decision_note
      )
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_shared_settlement_decided on public.shared_settlements;
create trigger trg_shared_settlement_decided
  after update of status on public.shared_settlements
  for each row execute function public.on_shared_settlement_decided();
