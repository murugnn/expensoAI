-- Add phone_masked column to user_profiles for cross-device persistence
-- This stores only the masked display value (e.g. "••••••3210"), never the raw number.

alter table public.user_profiles
  add column if not exists phone_masked text;

-- Update the RPC to also accept and store phone_masked
create or replace function public.update_my_profile_hashes(
  p_phone_hash text default null,
  p_email_hash text default null,
  p_phone_masked text default null
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
     set phone_hash   = coalesce(nullif(p_phone_hash,''), phone_hash),
         email_hash   = coalesce(nullif(p_email_hash,''), email_hash),
         phone_masked = coalesce(nullif(p_phone_masked,''), phone_masked),
         updated_at   = now()
   where id = uid;
end;
$$;
