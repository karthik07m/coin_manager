-- Monthly cloud-AI allowance per app user (anonymous Supabase Auth users).
-- Only the finance-ai edge function touches this, with the service role.

create table if not exists public.ai_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  month date not null,
  count integer not null default 0,
  primary key (user_id, month)
);

-- RLS on with no policies: invisible to anon/authenticated clients.
alter table public.ai_usage enable row level security;

-- Uses one credit for the current month (UTC) if any are left.
-- Returns credits remaining after this request, or -1 when used up.
-- Insert-or-increment is one statement, so concurrent requests can't both
-- take the last credit.
create or replace function public.consume_ai_credit(p_user uuid, p_limit integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month date := date_trunc('month', timezone('utc', now()))::date;
  v_count integer;
begin
  if p_limit <= 0 then
    return -1;
  end if;

  insert into public.ai_usage as u (user_id, month, count)
  values (p_user, v_month, 1)
  on conflict (user_id, month) do update
    set count = u.count + 1
    where u.count < p_limit
  returning u.count into v_count;

  if v_count is null then
    return -1;
  end if;
  return p_limit - v_count;
end;
$$;

-- Users must not be able to call this themselves (PostgREST exposes public
-- functions to anon/authenticated by default).
revoke all on function public.consume_ai_credit(uuid, integer) from public, anon, authenticated;
grant execute on function public.consume_ai_credit(uuid, integer) to service_role;
