-- FILE: BLINDERS_0_3_8_IRIS_CONTROL_SUBMENUS.sql
-- ============================================================
-- BLINDERS CASSINO — 0.3.8 IRIS CONTROL + SUBMENUS
-- Novo gerenciamento IRIS + menu hambúrguer organizado em submenus.
-- Rode depois da última atualização.
-- Resultado esperado: BLINDERS_0_3_8_IRIS_CONTROL_SUBMENUS_OK
-- ============================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ------------------------------------------------------------
-- Compatibilidade de tabelas base
-- ------------------------------------------------------------
alter table public.app_members add column if not exists balance_virtual_units numeric(40,2) not null default 0;
alter table public.app_members add column if not exists zarcovi_account text;
alter table public.app_members add column if not exists iris_member_id text;
alter table public.app_members add column if not exists friend_code text;
alter table public.app_members add column if not exists status text not null default 'pending';
alter table public.app_members add column if not exists role text not null default 'user';
alter table public.app_members add column if not exists updated_at timestamptz default now();

create table if not exists public.iris_bank_accounts_mod020 (
  bank_key text primary key,
  display_name text not null,
  iris_id text not null unique,
  balance_units numeric(40,2) not null default 0,
  deposits_total_units numeric(40,2) not null default 0,
  table_fee_units numeric(40,2) not null default 0,
  solo_profit_units numeric(40,2) not null default 0,
  updated_at timestamptz default now()
);

alter table public.iris_bank_accounts_mod020 add column if not exists reserve_percent numeric(8,2) not null default 10;
alter table public.iris_bank_accounts_mod020 add column if not exists max_single_prize_percent numeric(8,2) not null default 10;
alter table public.iris_bank_accounts_mod020 add column if not exists status text not null default 'active';

insert into public.iris_bank_accounts_mod020(bank_key,display_name,iris_id)
values('EMSHBY','Banco EMSHBY','EMSHBY')
on conflict(bank_key) do nothing;

create table if not exists public.iris_transactions (
  id uuid primary key default extensions.gen_random_uuid(),
  tx_code text unique default ('TX-' || upper(substr(encode(extensions.gen_random_bytes(6),'hex'),1,12))),
  astral_code text default ('AST-' || upper(substr(encode(extensions.gen_random_bytes(4),'hex'),1,8))),
  type text,
  status text default 'pending',
  from_member_id uuid references public.app_members(id) on delete set null,
  to_member_id uuid references public.app_members(id) on delete set null,
  from_account text,
  to_account text,
  amount_units numeric(40,2) default 0,
  description text,
  metadata jsonb not null default '{}',
  created_at timestamptz default now(),
  confirmed_at timestamptz
);

create table if not exists public.deposit_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  member_id uuid references public.app_members(id) on delete set null,
  amount_units numeric(40,2) default 0,
  account_used text,
  proof_url text,
  status text default 'pending',
  tx_id uuid,
  confirmed_by uuid references public.app_members(id) on delete set null,
  created_at timestamptz default now(),
  confirmed_at timestamptz
);

create table if not exists public.withdraw_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  member_id uuid references public.app_members(id) on delete set null,
  amount_units numeric(40,2) default 0,
  account text,
  link text,
  withdraw_code text default ('WD-' || upper(substr(encode(extensions.gen_random_bytes(4),'hex'),1,8))),
  status text default 'pending',
  tx_id uuid,
  confirmed_by uuid references public.app_members(id) on delete set null,
  created_at timestamptz default now(),
  confirmed_at timestamptz
);

create table if not exists public.official_game_rules (
  game_key text primary key,
  game_name text not null,
  mode text not null default 'individual',
  min_bet_units numeric(40,2) not null default 1500000000000,
  max_bet_units numeric(40,2) not null default 3000000000000,
  difficulty text not null default 'normal',
  payout_rule text not null default '',
  bank_rule text not null default '',
  max_players int not null default 1,
  requires_master boolean not null default false,
  quick_play boolean not null default true,
  active boolean not null default true,
  updated_at timestamptz default now()
);

create table if not exists public.zarcovi_live_accounts (
  account_code text primary key,
  source_key text not null default 'banco01',
  source_row int,
  kind text,
  vila text,
  level_num numeric(12,2) default 0,
  ryos_visible_b numeric(40,2) default 0,
  ryos_units numeric(40,2) default 0,
  salario_b numeric(40,2) default 0,
  salario_units numeric(40,2) default 0,
  cargos text,
  vontade_fogo numeric(12,2) default 0,
  vontade_pedra numeric(12,2) default 0,
  personagem text,
  tesouro_b numeric(40,2) default 0,
  tesouro_units numeric(40,2) default 0,
  raw_data jsonb not null default '{}',
  synced_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.official_system_flags (
  id int primary key default 1,
  safe_mode boolean not null default false,
  safe_message text not null default 'Modo seguro ativo. Jogos temporariamente pausados.',
  pwa_enabled boolean not null default true,
  updated_by uuid references public.app_members(id) on delete set null,
  updated_at timestamptz default now(),
  constraint official_system_flags_singleton_038 check(id=1)
);
insert into public.official_system_flags(id) values(1) on conflict(id) do nothing;

create table if not exists public.official_admin_audit (
  id uuid primary key default extensions.gen_random_uuid(),
  actor_member_id uuid references public.app_members(id) on delete set null,
  event_key text not null,
  message text,
  metadata jsonb not null default '{}',
  created_at timestamptz default now()
);

create table if not exists public.official_error_logs (
  id uuid primary key default extensions.gen_random_uuid(),
  category text not null default 'system',
  severity text not null default 'info',
  member_id uuid references public.app_members(id) on delete set null,
  route text,
  message text,
  metadata jsonb not null default '{}',
  status text not null default 'open',
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- IRIS Control tables
-- ------------------------------------------------------------
create table if not exists public.iris_control_settings_038 (
  id int primary key default 1,
  safe_mode boolean not null default false,
  safe_message text not null default 'Banco IRIS em modo seguro.',
  default_min_bet_units numeric(40,2) not null default 1500000000000,
  default_max_bet_units numeric(40,2) not null default 3000000000000,
  updated_by uuid references public.app_members(id) on delete set null,
  updated_at timestamptz default now(),
  constraint iris_control_settings_038_singleton check(id=1)
);
insert into public.iris_control_settings_038(id) values(1) on conflict(id) do nothing;

create table if not exists public.iris_account_flags_038 (
  member_id uuid primary key references public.app_members(id) on delete cascade,
  frozen boolean not null default false,
  frozen_reason text,
  risk_level text not null default 'normal',
  note text,
  updated_by uuid references public.app_members(id) on delete set null,
  updated_at timestamptz default now()
);

create table if not exists public.iris_balance_adjustments_038 (
  id uuid primary key default extensions.gen_random_uuid(),
  member_id uuid references public.app_members(id) on delete set null,
  admin_id uuid references public.app_members(id) on delete set null,
  amount_units numeric(40,2) not null default 0,
  old_balance_units numeric(40,2) not null default 0,
  new_balance_units numeric(40,2) not null default 0,
  reason text,
  tx_id uuid,
  created_at timestamptz default now()
);

create table if not exists public.iris_reconcile_reports_038 (
  id uuid primary key default extensions.gen_random_uuid(),
  member_id uuid references public.app_members(id) on delete set null,
  zarcovi_account text,
  iris_balance_units numeric(40,2) default 0,
  zarcovi_balance_units numeric(40,2) default 0,
  difference_units numeric(40,2) default 0,
  status text default 'checked',
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- Helper functions
-- ------------------------------------------------------------
drop function if exists public.app_iris38_is_admin(public.app_members);
create or replace function public.app_iris38_is_admin(m public.app_members)
returns boolean language sql stable as $$
  select coalesce(m.role,'user') in ('admin','owner')
$$;

drop function if exists public.app_iris38_format(numeric);
create or replace function public.app_iris38_format(p_units numeric)
returns text
language plpgsql
immutable
as $$
declare
  v numeric := coalesce(p_units,0);
begin
  if abs(v) >= 1000000000000 then
    return trim(to_char(v/1000000000000,'FM999999999999990D00')) || 'T';
  end if;
  if abs(v) >= 1000000000 then
    return trim(to_char(v/1000000000,'FM999999999999990D00')) || 'B';
  end if;
  return trim(to_char(v,'FM999999999999990D00'));
end;
$$;

drop function if exists public.app_iris38_parse(text);
create or replace function public.app_iris38_parse(p_amount text)
returns numeric
language plpgsql
immutable
as $$
declare
  s text := upper(trim(coalesce(p_amount,'')));
  n numeric;
begin
  if s='' then return 0; end if;
  s := replace(s,',','.');
  if s like '%T' then
    n := nullif(regexp_replace(s,'[^0-9.\-]','','g'),'')::numeric;
    return n * 1000000000000;
  elsif s like '%B' then
    n := nullif(regexp_replace(s,'[^0-9.\-]','','g'),'')::numeric;
    return n * 1000000000;
  else
    return nullif(regexp_replace(s,'[^0-9.\-]','','g'),'')::numeric;
  end if;
exception when others then
  return 0;
end;
$$;

drop function if exists public.app_iris38_audit_log(uuid,text,text,jsonb);
create or replace function public.app_iris38_audit_log(p_actor uuid,p_action text,p_message text,p_metadata jsonb default '{}')
returns void
language plpgsql
security definer
set search_path=public,extensions
as $$
begin
  insert into public.official_admin_audit(actor_member_id,event_key,message,metadata)
  values(p_actor,p_action,p_message,coalesce(p_metadata,'{}'::jsonb));
end;
$$;

-- ------------------------------------------------------------
-- RPCs
-- ------------------------------------------------------------
drop function if exists public.app_iris38_overview(text);
create or replace function public.app_iris38_overview(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  a public.app_members;
  members_balance numeric;
  vault numeric;
  active_accounts int;
  frozen_accounts int;
  tx_today int;
  open_alerts int;
  pending_dep int;
  pending_wd int;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;

  select coalesce(sum(balance_virtual_units),0) into members_balance from public.app_members;
  select coalesce(balance_units,0) into vault from public.iris_bank_accounts_mod020 where bank_key='EMSHBY';
  select count(*) into active_accounts from public.app_members where status in ('active','confirmed','approved');
  select count(*) into frozen_accounts from public.iris_account_flags_038 where frozen=true;
  select count(*) into tx_today from public.iris_transactions where created_at::date=current_date;
  select count(*) into open_alerts from public.official_error_logs where status='open';
  select count(*) into pending_dep from public.deposit_requests where status='pending';
  select count(*) into pending_wd from public.withdraw_requests where status='pending';

  return jsonb_build_object('ok',true,'summary',jsonb_build_object(
    'membersBalanceLabel',public.app_iris38_format(members_balance),
    'vaultLabel',public.app_iris38_format(vault),
    'activeAccounts',active_accounts,
    'frozenAccounts',frozen_accounts,
    'transactionsToday',tx_today,
    'openAlerts',open_alerts,
    'pendingDeposits',pending_dep,
    'pendingWithdraws',pending_wd,
    'message','IRIS Control ativo. Use os submenus para gerenciar cada área do banco.'
  ));
end;
$$;

drop function if exists public.app_iris38_search_accounts(text,text);
create or replace function public.app_iris38_search_accounts(p_token text,p_query text default '')
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  a public.app_members;
  q text := lower(trim(coalesce(p_query,'')));
  rows jsonb;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',m.id,
    'nick',m.nick,
    'role',m.role,
    'status',m.status,
    'zarcoviAccount',coalesce(m.zarcovi_account,''),
    'irisId',coalesce(m.iris_member_id,''),
    'friendCode',coalesce(m.friend_code,''),
    'balanceLabel',public.app_iris38_format(m.balance_virtual_units),
    'frozen',coalesce(f.frozen,false)
  ) order by m.created_at desc),'[]'::jsonb)
  into rows
  from public.app_members m
  left join public.iris_account_flags_038 f on f.member_id=m.id
  where q=''
     or lower(coalesce(m.nick,'')) like '%'||q||'%'
     or lower(coalesce(m.zarcovi_account,'')) like '%'||q||'%'
     or lower(coalesce(m.iris_member_id,'')) like '%'||q||'%'
     or lower(coalesce(m.friend_code,'')) like '%'||q||'%'
  limit 80;

  return jsonb_build_object('ok',true,'accounts',rows);
end;
$$;

drop function if exists public.app_iris38_transactions(text,int);
create or replace function public.app_iris38_transactions(p_token text,p_limit int default 80)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  a public.app_members;
  rows jsonb;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'createdAt',to_char(t.created_at,'DD/MM HH24:MI'),
    'txCode',coalesce(t.tx_code,'-'),
    'astralCode',coalesce(t.astral_code,'-'),
    'type',coalesce(t.type,'-'),
    'from',coalesce(t.from_account, fm.nick, '-'),
    'to',coalesce(t.to_account, tm.nick, '-'),
    'amountLabel',public.app_iris38_format(t.amount_units),
    'status',coalesce(t.status,'-')
  ) order by t.created_at desc),'[]'::jsonb)
  into rows
  from public.iris_transactions t
  left join public.app_members fm on fm.id=t.from_member_id
  left join public.app_members tm on tm.id=t.to_member_id
  limit greatest(1,least(coalesce(p_limit,80),200));

  return jsonb_build_object('ok',true,'transactions',rows);
end;
$$;

drop function if exists public.app_iris38_vault(text);
create or replace function public.app_iris38_vault(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  a public.app_members;
  b public.iris_bank_accounts_mod020;
  reserve numeric;
  available numeric;
  maxp numeric;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;

  select * into b from public.iris_bank_accounts_mod020 where bank_key='EMSHBY';
  reserve := coalesce(b.balance_units,0) * (coalesce(b.reserve_percent,10)/100);
  available := greatest(coalesce(b.balance_units,0)-reserve,0);
  maxp := least(available, coalesce(b.balance_units,0)*(coalesce(b.max_single_prize_percent,10)/100));

  return jsonb_build_object('ok',true,'vault',jsonb_build_object(
    'balanceLabel',public.app_iris38_format(coalesce(b.balance_units,0)),
    'reserveLabel',public.app_iris38_format(reserve),
    'availableLabel',public.app_iris38_format(available),
    'maxPrizeLabel',public.app_iris38_format(maxp),
    'reservePercent',coalesce(b.reserve_percent,10),
    'maxPrizePercent',coalesce(b.max_single_prize_percent,10),
    'status',coalesce(b.status,'active')
  ));
end;
$$;

drop function if exists public.app_iris38_set_vault_rules(text,numeric,numeric);
create or replace function public.app_iris38_set_vault_rules(p_token text,p_reserve_percent numeric,p_max_prize_percent numeric)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  a public.app_members;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;

  update public.iris_bank_accounts_mod020
  set reserve_percent=least(greatest(coalesce(p_reserve_percent,10),0),90),
      max_single_prize_percent=least(greatest(coalesce(p_max_prize_percent,10),1),90),
      updated_at=now()
  where bank_key='EMSHBY';

  perform public.app_iris38_audit_log(a.id,'iris_vault_rules','Regras do cofre EMSHBY alteradas',jsonb_build_object('reserve',p_reserve_percent,'maxPrize',p_max_prize_percent));
  return jsonb_build_object('ok',true);
end;
$$;

drop function if exists public.app_iris38_deposits(text);
create or replace function public.app_iris38_deposits(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare a public.app_members; rows jsonb;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'member',coalesce(m.nick,'-'),
    'account',coalesce(d.account_used,m.zarcovi_account,'-'),
    'amountLabel',public.app_iris38_format(d.amount_units),
    'status',coalesce(d.status,'-'),
    'createdAt',to_char(d.created_at,'DD/MM HH24:MI')
  ) order by d.created_at desc),'[]'::jsonb) into rows
  from public.deposit_requests d left join public.app_members m on m.id=d.member_id
  limit 100;
  return jsonb_build_object('ok',true,'deposits',rows);
end;
$$;

drop function if exists public.app_iris38_withdraws(text);
create or replace function public.app_iris38_withdraws(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare a public.app_members; rows jsonb;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'member',coalesce(m.nick,'-'),
    'account',coalesce(w.account,m.zarcovi_account,'-'),
    'amountLabel',public.app_iris38_format(w.amount_units),
    'code',coalesce(w.withdraw_code,'-'),
    'status',coalesce(w.status,'-'),
    'createdAt',to_char(w.created_at,'DD/MM HH24:MI')
  ) order by w.created_at desc),'[]'::jsonb) into rows
  from public.withdraw_requests w left join public.app_members m on m.id=w.member_id
  limit 100;
  return jsonb_build_object('ok',true,'withdraws',rows);
end;
$$;

drop function if exists public.app_iris38_reconcile_zarcovi(text);
create or replace function public.app_iris38_reconcile_zarcovi(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  a public.app_members;
  rows jsonb;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;

  delete from public.iris_reconcile_reports_038 where created_at < now() - interval '7 days';

  insert into public.iris_reconcile_reports_038(member_id,zarcovi_account,iris_balance_units,zarcovi_balance_units,difference_units,status)
  select m.id, upper(coalesce(m.zarcovi_account,m.nick,'')), m.balance_virtual_units, coalesce(z.ryos_units,0), m.balance_virtual_units - coalesce(z.ryos_units,0),
    case when z.account_code is null then 'missing_in_sheet' when m.balance_virtual_units = z.ryos_units then 'ok' else 'difference' end
  from public.app_members m
  left join public.zarcovi_live_accounts z on z.account_code=upper(coalesce(m.zarcovi_account,m.nick,''));

  select coalesce(jsonb_agg(jsonb_build_object(
    'nick',m.nick,
    'account',r.zarcovi_account,
    'iris',public.app_iris38_format(r.iris_balance_units),
    'zarcovi',public.app_iris38_format(r.zarcovi_balance_units),
    'difference',public.app_iris38_format(r.difference_units),
    'status',r.status
  ) order by abs(r.difference_units) desc),'[]'::jsonb)
  into rows
  from public.iris_reconcile_reports_038 r
  left join public.app_members m on m.id=r.member_id
  where r.created_at > now() - interval '5 minutes'
  limit 150;

  perform public.app_iris38_audit_log(a.id,'iris_reconcile','Conciliação IRIS x Zarcovi executada',jsonb_build_object('count',jsonb_array_length(rows)));
  return jsonb_build_object('ok',true,'rows',rows);
end;
$$;

drop function if exists public.app_iris38_limits(text);
create or replace function public.app_iris38_limits(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare a public.app_members; rows jsonb;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'gameKey',game_key,
    'gameName',game_name,
    'minLabel',public.app_iris38_format(min_bet_units),
    'maxLabel',public.app_iris38_format(max_bet_units),
    'active',active
  ) order by game_name),'[]'::jsonb) into rows
  from public.official_game_rules;
  return jsonb_build_object('ok',true,'rules',rows);
end;
$$;

drop function if exists public.app_iris38_apply_default_limits(text);
create or replace function public.app_iris38_apply_default_limits(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare a public.app_members;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  update public.official_game_rules set min_bet_units=1500000000000,max_bet_units=3000000000000,updated_at=now();
  update public.iris_control_settings_038 set default_min_bet_units=1500000000000,default_max_bet_units=3000000000000,updated_by=a.id,updated_at=now() where id=1;
  perform public.app_iris38_audit_log(a.id,'iris_limits_default','Limites padrão 1,5T/3T aplicados','{}'::jsonb);
  return jsonb_build_object('ok',true);
end;
$$;

drop function if exists public.app_iris38_audit(text);
create or replace function public.app_iris38_audit(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare a public.app_members; rows jsonb;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'createdAt',to_char(oa.created_at,'DD/MM HH24:MI'),
    'actor',coalesce(am.nick,'sistema'),
    'action',oa.event_key,
    'message',oa.message
  ) order by oa.created_at desc),'[]'::jsonb) into rows
  from public.official_admin_audit oa
  left join public.app_members am on am.id=oa.actor_member_id
  where oa.event_key like 'iris_%'
  limit 120;
  return jsonb_build_object('ok',true,'rows',rows);
end;
$$;

drop function if exists public.app_iris38_safe_state(text);
create or replace function public.app_iris38_safe_state(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare a public.app_members; s boolean;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  select safe_mode into s from public.iris_control_settings_038 where id=1;
  return jsonb_build_object('ok',true,'safeMode',coalesce(s,false));
end;
$$;

drop function if exists public.app_iris38_toggle_safe(text,boolean);
create or replace function public.app_iris38_toggle_safe(p_token text,p_enabled boolean)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare a public.app_members;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  update public.iris_control_settings_038 set safe_mode=coalesce(p_enabled,false),updated_by=a.id,updated_at=now() where id=1;
  update public.official_system_flags set safe_mode=coalesce(p_enabled,false),updated_by=a.id,updated_at=now() where id=1;
  perform public.app_iris38_audit_log(a.id,'iris_safe_mode','Modo seguro IRIS alterado',jsonb_build_object('enabled',p_enabled));
  return jsonb_build_object('ok',true,'safeMode',p_enabled);
end;
$$;

drop function if exists public.app_iris38_set_account_freeze(text,uuid,boolean,text);
create or replace function public.app_iris38_set_account_freeze(p_token text,p_member_id uuid,p_frozen boolean,p_reason text default '')
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare a public.app_members;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;

  insert into public.iris_account_flags_038(member_id,frozen,frozen_reason,updated_by,updated_at)
  values(p_member_id,coalesce(p_frozen,false),p_reason,a.id,now())
  on conflict(member_id) do update set frozen=excluded.frozen,frozen_reason=excluded.frozen_reason,updated_by=a.id,updated_at=now();

  perform public.app_iris38_audit_log(a.id,'iris_account_freeze','Status de congelamento alterado',jsonb_build_object('memberId',p_member_id,'frozen',p_frozen,'reason',p_reason));
  return jsonb_build_object('ok',true);
end;
$$;

drop function if exists public.app_iris38_adjust_balance(text,uuid,text,text);
create or replace function public.app_iris38_adjust_balance(p_token text,p_member_id uuid,p_amount text,p_reason text default 'Ajuste manual IRIS')
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  a public.app_members;
  m public.app_members;
  amount numeric;
  oldbal numeric;
  newbal numeric;
  tid uuid;
begin
  a := public.v25_current(p_token);
  if not public.app_iris38_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;

  select * into m from public.app_members where id=p_member_id for update;
  if m.id is null then raise exception 'Conta não encontrada.'; end if;

  amount := public.app_iris38_parse(p_amount);
  if amount=0 then raise exception 'Valor inválido.'; end if;

  oldbal := coalesce(m.balance_virtual_units,0);
  newbal := oldbal + amount;
  if newbal < 0 then raise exception 'Ajuste deixaria saldo negativo.'; end if;

  update public.app_members set balance_virtual_units=newbal, updated_at=now() where id=m.id;

  insert into public.iris_transactions(type,status,from_member_id,to_member_id,from_account,to_account,amount_units,description,metadata,confirmed_at)
  values('iris_adjustment','completed',a.id,m.id,coalesce(a.iris_member_id,a.nick),coalesce(m.iris_member_id,m.nick),amount,p_reason,jsonb_build_object('oldBalance',oldbal,'newBalance',newbal,'admin',a.nick),now())
  returning id into tid;

  insert into public.iris_balance_adjustments_038(member_id,admin_id,amount_units,old_balance_units,new_balance_units,reason,tx_id)
  values(m.id,a.id,amount,oldbal,newbal,p_reason,tid);

  perform public.app_iris38_audit_log(a.id,'iris_balance_adjustment','Ajuste manual de saldo IRIS',jsonb_build_object('member',m.nick,'amount',amount,'old',oldbal,'new',newbal,'reason',p_reason));
  return jsonb_build_object('ok',true,'newBalanceLabel',public.app_iris38_format(newbal));
end;
$$;

-- Rotas
insert into public.app_routes(route_key,route_title,route_path,route_group,requires_role,icon,display_order,active,updated_at)
values
('iris_control_038','IRIS Control','/owner/iris-control.html','admin','admin','iris',43,true,now())
on conflict(route_key) do update set
  route_title=excluded.route_title,
  route_path=excluded.route_path,
  route_group=excluded.route_group,
  requires_role=excluded.requires_role,
  icon=excluded.icon,
  display_order=excluded.display_order,
  active=true,
  updated_at=now();

grant execute on function public.app_iris38_format(numeric) to anon, authenticated;
grant execute on function public.app_iris38_parse(text) to anon, authenticated;
grant execute on function public.app_iris38_overview(text) to anon, authenticated;
grant execute on function public.app_iris38_search_accounts(text,text) to anon, authenticated;
grant execute on function public.app_iris38_transactions(text,int) to anon, authenticated;
grant execute on function public.app_iris38_vault(text) to anon, authenticated;
grant execute on function public.app_iris38_set_vault_rules(text,numeric,numeric) to anon, authenticated;
grant execute on function public.app_iris38_deposits(text) to anon, authenticated;
grant execute on function public.app_iris38_withdraws(text) to anon, authenticated;
grant execute on function public.app_iris38_reconcile_zarcovi(text) to anon, authenticated;
grant execute on function public.app_iris38_limits(text) to anon, authenticated;
grant execute on function public.app_iris38_apply_default_limits(text) to anon, authenticated;
grant execute on function public.app_iris38_audit(text) to anon, authenticated;
grant execute on function public.app_iris38_safe_state(text) to anon, authenticated;
grant execute on function public.app_iris38_toggle_safe(text,boolean) to anon, authenticated;
grant execute on function public.app_iris38_set_account_freeze(text,uuid,boolean,text) to anon, authenticated;
grant execute on function public.app_iris38_adjust_balance(text,uuid,text,text) to anon, authenticated;

notify pgrst, 'reload schema';

select 'BLINDERS_0_3_8_IRIS_CONTROL_SUBMENUS_OK' as status;
