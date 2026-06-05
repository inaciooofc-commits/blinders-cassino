-- ============================================================
-- BLINDERS CASSINO — SQL COMPLETO DAS ATUALIZAÇÕES DISPONÍVEIS
-- Cole no Supabase SQL Editor se quiser reaplicar a sequência completa.
-- Para banco já atualizado, use só SQL_PARA_COLAR_NO_SUPABASE.sql.
-- ============================================================


-- ============================================================
-- ZIP: blinders-cassino-0-3-oficial-estavel-sql.zip
-- FILE: BLINDERS_0_3_OFICIAL_ESTAVEL.sql
-- ============================================================

-- ============================================================
-- BLINDERS CASSINO — 0.3 OFICIAL ESTÁVEL
-- Mantém atualizações novas e consolida todos os módulos pedidos.
-- Rode depois do último SQL aplicado.
-- Resultado esperado: BLINDERS_0_3_OFICIAL_ESTAVEL_OK
-- ============================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ------------------------------------------------------------
-- 1. Estabilidade geral, backup, saúde, logs e modo seguro
-- ------------------------------------------------------------
create table if not exists public.official_stable_backups (
  id uuid primary key default extensions.gen_random_uuid(),
  backup_code text unique not null default ('BKP-' || upper(substr(encode(extensions.gen_random_bytes(5),'hex'),1,10))),
  label text not null default 'Backup estável',
  app_version text not null default '0.3 oficial',
  metadata jsonb not null default '{}',
  created_by uuid references public.app_members(id) on delete set null,
  created_at timestamptz default now()
);

create table if not exists public.official_system_flags (
  id int primary key default 1,
  safe_mode boolean not null default false,
  safe_message text not null default 'Modo seguro ativo. Jogos temporariamente pausados.',
  pwa_enabled boolean not null default true,
  updated_by uuid references public.app_members(id) on delete set null,
  updated_at timestamptz default now(),
  constraint official_system_flags_singleton check(id=1)
);

insert into public.official_system_flags(id) values(1) on conflict(id) do nothing;

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

create table if not exists public.official_admin_audit (
  id uuid primary key default extensions.gen_random_uuid(),
  actor_member_id uuid references public.app_members(id) on delete set null,
  event_key text not null,
  message text,
  metadata jsonb not null default '{}',
  created_at timestamptz default now()
);

create table if not exists public.official_health_checks (
  id uuid primary key default extensions.gen_random_uuid(),
  check_key text not null,
  status text not null default 'ok',
  details jsonb not null default '{}',
  checked_at timestamptz default now()
);

-- ------------------------------------------------------------
-- 2. Cofre EMSHBY e Banco IRIS
-- ------------------------------------------------------------
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

alter table public.iris_bank_accounts_mod020 add column if not exists withdraw_paid_units numeric(40,2) not null default 0;
alter table public.iris_bank_accounts_mod020 add column if not exists bonus_distributed_units numeric(40,2) not null default 0;
alter table public.iris_bank_accounts_mod020 add column if not exists reserve_percent numeric(8,2) not null default 10;
alter table public.iris_bank_accounts_mod020 add column if not exists max_single_prize_percent numeric(8,2) not null default 10;
alter table public.iris_bank_accounts_mod020 add column if not exists status text not null default 'active';

insert into public.iris_bank_accounts_mod020(bank_key,display_name,iris_id)
values('EMSHBY','Banco EMSHBY','EMSHBY')
on conflict(bank_key) do nothing;

create table if not exists public.emshby_ledger (
  id uuid primary key default extensions.gen_random_uuid(),
  entry_type text not null,
  direction text not null,
  amount_units numeric(40,2) not null default 0,
  tx_code text,
  source text,
  description text,
  metadata jsonb not null default '{}',
  created_at timestamptz default now()
);

create table if not exists public.emshby_reports (
  id uuid primary key default extensions.gen_random_uuid(),
  report_type text not null,
  period_start date not null,
  period_end date not null,
  deposits_units numeric(40,2) not null default 0,
  table_fee_units numeric(40,2) not null default 0,
  solo_profit_units numeric(40,2) not null default 0,
  withdraw_paid_units numeric(40,2) not null default 0,
  bonus_distributed_units numeric(40,2) not null default 0,
  final_balance_units numeric(40,2) not null default 0,
  metadata jsonb not null default '{}',
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- 3. Jogos, regras, limites, histórico e ranking
-- ------------------------------------------------------------
create table if not exists public.official_game_rules (
  game_key text primary key,
  game_name text not null,
  mode text not null default 'individual',
  min_bet_units numeric(40,2) not null default 1000000000,
  max_bet_units numeric(40,2) not null default 1000000000000,
  difficulty text not null default 'normal',
  payout_rule text not null,
  bank_rule text not null,
  max_players int not null default 1,
  requires_master boolean not null default false,
  quick_play boolean not null default true,
  active boolean not null default true,
  updated_at timestamptz default now()
);

insert into public.official_game_rules(game_key,game_name,mode,min_bet_units,max_bet_units,difficulty,payout_rule,bank_rule,max_players,requires_master,quick_play)
values
('blackjack','Blackjack','mesa',1000000000,1000000000000,'normal','Mesa com pote. Vencedor recebe pote - 5% de comissão.','Comissão de 5% vai para EMSHBY.',2,true,false),
('bingo','Bingo','mesa',1000000000,1000000000000,'normal','Mesa com pote. Vencedor recebe pote - 5% de comissão.','Comissão de 5% vai para EMSHBY.',5,true,false),
('dados','Dados','mesa',1000000000,1000000000000,'normal','Mesa com pote. Vencedor recebe pote - 5% de comissão.','Comissão de 5% vai para EMSHBY.',4,true,false),
('roleta','Roleta','mesa',1000000000,1000000000000,'normal','Mesa com pote. Vencedor recebe pote - 5% de comissão.','Comissão de 5% vai para EMSHBY.',5,true,false),
('slots','Slots','individual',1000000000,1000000000000,'normal','Vitória paga 2x. Derrota fica no banco.','Perdas vão para EMSHBY.',1,false,true),
('crash','Crash','individual',1000000000,1000000000000,'normal','Vitória paga 2x. Derrota fica no banco.','Perdas vão para EMSHBY.',1,false,true),
('memoria','Memória','individual',1000000000,1000000000000,'normal','Vitória paga 2x. Derrota fica no banco.','Perdas vão para EMSHBY.',1,false,true),
('mines','Mines','individual',1000000000,1000000000000,'normal','Vitória paga 2x. Derrota fica no banco.','Perdas vão para EMSHBY.',1,false,true),
('plinko','Plinko','individual',1000000000,1000000000000,'normal','Vitória paga 2x. Derrota fica no banco.','Perdas vão para EMSHBY.',1,false,true),
('coinflip','Coin Flip','individual',1000000000,1000000000000,'normal','Vitória paga 2x. Derrota fica no banco.','Perdas vão para EMSHBY.',1,false,true),
('baccarat','Baccarat','individual',1000000000,1000000000000,'normal','Vitória paga 2x. Derrota fica no banco.','Perdas vão para EMSHBY.',1,false,true)
on conflict(game_key) do update set
  game_name=excluded.game_name,
  mode=excluded.mode,
  min_bet_units=excluded.min_bet_units,
  max_bet_units=excluded.max_bet_units,
  difficulty=excluded.difficulty,
  payout_rule=excluded.payout_rule,
  bank_rule=excluded.bank_rule,
  max_players=excluded.max_players,
  requires_master=excluded.requires_master,
  quick_play=excluded.quick_play,
  active=true,
  updated_at=now();

create table if not exists public.official_game_history (
  id uuid primary key default extensions.gen_random_uuid(),
  member_id uuid references public.app_members(id) on delete set null,
  game_key text not null,
  bet_units numeric(40,2) not null default 0,
  prize_units numeric(40,2) not null default 0,
  outcome text not null,
  tx_code text,
  astral_code text,
  metadata jsonb not null default '{}',
  created_at timestamptz default now()
);

create table if not exists public.official_private_tables (
  id uuid primary key default extensions.gen_random_uuid(),
  invite_code text unique not null default ('MESA-' || upper(substr(encode(extensions.gen_random_bytes(4),'hex'),1,8))),
  table_id uuid,
  created_by uuid references public.app_members(id) on delete set null,
  active boolean not null default true,
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- 4. Bônus e eventos
-- ------------------------------------------------------------
create table if not exists public.bonus_codes_mod030 (
  code text primary key,
  money_units numeric(40,2) not null default 0,
  max_uses int not null default 1,
  used_count int not null default 0,
  active boolean not null default true,
  created_by uuid references public.app_members(id) on delete set null,
  created_at timestamptz default now(),
  expires_at timestamptz
);

alter table public.bonus_codes_mod030 add column if not exists role_required text;
alter table public.bonus_codes_mod030 add column if not exists clan_id uuid;
alter table public.bonus_codes_mod030 add column if not exists new_members_only boolean not null default false;
alter table public.bonus_codes_mod030 add column if not exists secret_event boolean not null default false;

create table if not exists public.bonus_code_items_mod030 (
  code text references public.bonus_codes_mod030(code) on delete cascade,
  item_key text not null,
  primary key(code,item_key)
);

create table if not exists public.bonus_redemptions_mod030 (
  id uuid primary key default extensions.gen_random_uuid(),
  code text references public.bonus_codes_mod030(code) on delete cascade,
  member_id uuid references public.app_members(id) on delete cascade,
  money_units numeric(40,2) not null default 0,
  items jsonb not null default '[]',
  redeemed_at timestamptz default now(),
  unique(code,member_id)
);

create table if not exists public.official_events (
  id uuid primary key default extensions.gen_random_uuid(),
  event_key text unique not null,
  title text not null,
  description text,
  kind text not null default 'daily',
  active boolean not null default true,
  starts_at timestamptz default now(),
  ends_at timestamptz,
  metadata jsonb not null default '{}',
  created_at timestamptz default now()
);

insert into public.official_events(event_key,title,description,kind,active)
values
('daily_bonus','Bônus diário','Resgate códigos liberados pela staff e acompanhe eventos do dia.','daily',true),
('weekly_rank','Ranking semanal','Jogue para subir no ranking de ganhos e apostas.','weekly',true),
('clan_missions','Missões de clã','Clãs podem participar de missões e eventos especiais.','weekly',true)
on conflict(event_key) do update set title=excluded.title,description=excluded.description,kind=excluded.kind,active=true;

-- ------------------------------------------------------------
-- 5. Admin, permissões, ban/mute, denúncias, notificações
-- ------------------------------------------------------------
create table if not exists public.official_roles (
  role_key text primary key,
  title text not null,
  level int not null default 1,
  permissions jsonb not null default '{}'
);

insert into public.official_roles(role_key,title,level,permissions)
values
('owner','Dono',100,'{"all":true}'),
('admin','Admin',80,'{"admin":true,"confirm":true,"moderate":true}'),
('table_master','Mestre de mesa',50,'{"tables":true}'),
('commissary','Comissária',40,'{"clans":true}'),
('moderator','Moderador',30,'{"chat_moderate":true}'),
('user','Membro comum',1,'{"play":true}')
on conflict(role_key) do update set title=excluded.title,level=excluded.level,permissions=excluded.permissions;

create table if not exists public.official_member_status (
  member_id uuid primary key references public.app_members(id) on delete cascade,
  banned_until timestamptz,
  muted_until timestamptz,
  suspicious boolean not null default false,
  notes text,
  updated_by uuid references public.app_members(id) on delete set null,
  updated_at timestamptz default now()
);

create table if not exists public.official_user_reports (
  id uuid primary key default extensions.gen_random_uuid(),
  reporter_member_id uuid references public.app_members(id) on delete set null,
  target_member_id uuid references public.app_members(id) on delete set null,
  category text not null default 'geral',
  message text,
  status text not null default 'open',
  created_at timestamptz default now(),
  resolved_by uuid references public.app_members(id) on delete set null,
  resolved_at timestamptz
);

-- ------------------------------------------------------------
-- 6. Segurança, PIN IRIS, login attempts, recovery e sessões
-- ------------------------------------------------------------
alter table public.app_members add column if not exists friend_code text;
alter table public.app_members add column if not exists iris_pin_hash text;
alter table public.app_members add column if not exists last_login_at timestamptz;
alter table public.app_members add column if not exists suspicious boolean not null default false;

update public.app_members
set friend_code='FR-' || upper(substr(encode(extensions.gen_random_bytes(5),'hex'),1,10))
where friend_code is null or trim(friend_code)='';

create unique index if not exists uq_app_members_friend_code_official on public.app_members(friend_code);

create table if not exists public.official_login_attempts (
  id uuid primary key default extensions.gen_random_uuid(),
  identifier text,
  success boolean not null default false,
  ip_hint text,
  user_agent text,
  message text,
  created_at timestamptz default now()
);

create table if not exists public.official_recovery_codes (
  id uuid primary key default extensions.gen_random_uuid(),
  member_id uuid references public.app_members(id) on delete cascade,
  recovery_code text not null,
  status text not null default 'active',
  created_at timestamptz default now(),
  used_at timestamptz
);

-- ------------------------------------------------------------
-- 7. Chat e amigos
-- ------------------------------------------------------------
create table if not exists public.member_friends_mod020 (
  id uuid primary key default extensions.gen_random_uuid(),
  member_id uuid not null references public.app_members(id) on delete cascade,
  friend_member_id uuid not null references public.app_members(id) on delete cascade,
  status text not null default 'accepted',
  created_at timestamptz default now(),
  unique(member_id, friend_member_id)
);

create table if not exists public.global_chat_messages_mod020 (
  id uuid primary key default extensions.gen_random_uuid(),
  member_id uuid not null references public.app_members(id) on delete cascade,
  body text not null,
  status text not null default 'active',
  created_at timestamptz default now()
);

create table if not exists public.official_private_messages (
  id uuid primary key default extensions.gen_random_uuid(),
  from_member_id uuid references public.app_members(id) on delete set null,
  to_member_id uuid references public.app_members(id) on delete set null,
  body text not null,
  status text not null default 'active',
  created_at timestamptz default now()
);

create table if not exists public.official_member_blocks (
  blocker_member_id uuid references public.app_members(id) on delete cascade,
  blocked_member_id uuid references public.app_members(id) on delete cascade,
  created_at timestamptz default now(),
  primary key(blocker_member_id, blocked_member_id)
);

create table if not exists public.official_pinned_messages (
  id uuid primary key default extensions.gen_random_uuid(),
  scope text not null default 'global',
  body text not null,
  pinned_by uuid references public.app_members(id) on delete set null,
  active boolean not null default true,
  created_at timestamptz default now()
);

create table if not exists public.official_clan_chat_messages (
  id uuid primary key default extensions.gen_random_uuid(),
  clan_id uuid,
  member_id uuid references public.app_members(id) on delete set null,
  body text not null,
  created_at timestamptz default now()
);

create table if not exists public.official_table_chat_messages (
  id uuid primary key default extensions.gen_random_uuid(),
  table_id uuid,
  member_id uuid references public.app_members(id) on delete set null,
  body text not null,
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- 8. Clãs e comissárias
-- ------------------------------------------------------------
create table if not exists public.clans_v34 (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  tag text not null unique,
  leader_member_id uuid references public.app_members(id) on delete set null,
  clan_iris_id text unique not null,
  balance_units numeric(40,2) not null default 0,
  status text not null default 'active',
  created_at timestamptz default now()
);

alter table public.clans_v34 add column if not exists coffer_units numeric(40,2) not null default 0;
alter table public.clans_v34 add column if not exists missions_completed int not null default 0;
alter table public.clans_v34 add column if not exists shop_enabled boolean not null default true;

create table if not exists public.clan_members_v34 (
  clan_id uuid references public.clans_v34(id) on delete cascade,
  member_id uuid references public.app_members(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz default now(),
  primary key(clan_id,member_id)
);

create table if not exists public.official_clan_transactions (
  id uuid primary key default extensions.gen_random_uuid(),
  clan_id uuid references public.clans_v34(id) on delete cascade,
  member_id uuid references public.app_members(id) on delete set null,
  tx_type text not null,
  amount_units numeric(40,2) not null default 0,
  description text,
  created_at timestamptz default now()
);

create table if not exists public.official_clan_missions (
  id uuid primary key default extensions.gen_random_uuid(),
  mission_key text unique not null,
  title text not null,
  description text,
  reward_units numeric(40,2) not null default 0,
  active boolean not null default true,
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- 9. Loja e inventário
-- ------------------------------------------------------------
create table if not exists public.member_inventory (
  id uuid primary key default extensions.gen_random_uuid(),
  member_id uuid references public.app_members(id) on delete cascade,
  item_key text,
  source text,
  created_at timestamptz default now()
);

alter table public.shop_items add column if not exists stock_limit int;
alter table public.shop_items add column if not exists sold_count int not null default 0;
alter table public.shop_items add column if not exists safe_equip_type text default 'none';
alter table public.shop_items add column if not exists event_item boolean not null default false;

create table if not exists public.official_shop_purchases (
  id uuid primary key default extensions.gen_random_uuid(),
  member_id uuid references public.app_members(id) on delete set null,
  item_key text,
  price_units numeric(40,2) not null default 0,
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- 10/11. Visual, performance, PWA
-- ------------------------------------------------------------
create table if not exists public.official_user_preferences (
  member_id uuid primary key references public.app_members(id) on delete cascade,
  lite_mode boolean not null default false,
  pwa_dont_remind boolean not null default false,
  device_type text,
  reduced_motion boolean not null default false,
  updated_at timestamptz default now()
);

-- ------------------------------------------------------------
-- Funções oficiais
-- ------------------------------------------------------------

drop function if exists public.app_official03_is_admin(public.app_members);
create or replace function public.app_official03_is_admin(m public.app_members)
returns boolean language sql stable as $$ select coalesce(m.role,'user') in ('admin','owner') $$;

drop function if exists public.app_official03_parse_amount(text);
create or replace function public.app_official03_parse_amount(p_amount text)
returns numeric language plpgsql immutable as $$
begin
  if coalesce(trim(p_amount),'')='' then return 0; end if;
  return public.v25_parse(p_amount);
end; $$;

drop function if exists public.app_official03_log(uuid,text,text,jsonb);
create or replace function public.app_official03_log(p_actor uuid,p_event text,p_message text,p_metadata jsonb default '{}')
returns void language plpgsql security definer set search_path=public,extensions as $$
begin
  insert into public.official_admin_audit(actor_member_id,event_key,message,metadata)
  values(p_actor,p_event,p_message,coalesce(p_metadata,'{}'::jsonb));
end; $$;

drop function if exists public.app_official03_create_backup(text,text);
create or replace function public.app_official03_create_backup(p_token text,p_label text default 'Backup manual')
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare a public.app_members; code text;
begin
  a:=public.v25_current(p_token);
  if not public.app_official03_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  insert into public.official_stable_backups(label,created_by,metadata)
  values(coalesce(nullif(p_label,''),'Backup manual'),a.id,jsonb_build_object('createdBy',a.nick,'source','admin_button'))
  returning backup_code into code;
  perform public.app_official03_log(a.id,'backup_created','Backup lógico criado',jsonb_build_object('backupCode',code));
  return jsonb_build_object('ok',true,'backupCode',code);
end; $$;

drop function if exists public.app_official03_toggle_safe_mode(text,boolean);
create or replace function public.app_official03_toggle_safe_mode(p_token text,p_enabled boolean)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare a public.app_members;
begin
  a:=public.v25_current(p_token);
  if not public.app_official03_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  update public.official_system_flags set safe_mode=coalesce(p_enabled,false),updated_by=a.id,updated_at=now() where id=1;
  perform public.app_official03_log(a.id,'safe_mode_changed','Modo seguro alterado',jsonb_build_object('enabled',p_enabled));
  return jsonb_build_object('ok',true,'safeMode',coalesce(p_enabled,false));
end; $$;

drop function if exists public.app_official03_health(text);
create or replace function public.app_official03_health(p_token text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare a public.app_members; result jsonb;
begin
  a:=public.v25_current(p_token);
  if not public.app_official03_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  result:=jsonb_build_object(
    'app_members',to_regclass('public.app_members') is not null,
    'iris_transactions',to_regclass('public.iris_transactions') is not null,
    'emshby_bank',exists(select 1 from public.iris_bank_accounts_mod020 where bank_key='EMSHBY'),
    'bonus_codes',to_regclass('public.bonus_codes_mod030') is not null,
    'chat',to_regclass('public.global_chat_messages_mod020') is not null,
    'clans',to_regclass('public.clans_v34') is not null,
    'safe_mode',(select safe_mode from public.official_system_flags where id=1),
    'checkedAt',now()
  );
  insert into public.official_health_checks(check_key,status,details) values('full_check','ok',result);
  return jsonb_build_object('ok',true,'health',result);
end; $$;

drop function if exists public.app_official03_admin_overview(text);
create or replace function public.app_official03_admin_overview(p_token text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare a public.app_members; b public.iris_bank_accounts_mod020; deposits_today numeric; accounts_today int; open_errors int; safe boolean;
begin
  a:=public.v25_current(p_token);
  if not public.app_official03_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  select * into b from public.iris_bank_accounts_mod020 where bank_key='EMSHBY';
  select coalesce(sum(amount_units),0) into deposits_today from public.deposit_requests where status='confirmed' and confirmed_at::date=current_date;
  select count(*) into accounts_today from public.app_members where created_at::date=current_date;
  select count(*) into open_errors from public.official_error_logs where status='open';
  select safe_mode into safe from public.official_system_flags where id=1;
  return jsonb_build_object('ok',true,'summary',jsonb_build_object(
    'vaultLabel',public.v25_format(coalesce(b.balance_units,0)),
    'depositsTodayLabel',public.v25_format(coalesce(deposits_today,0)),
    'tableFeesLabel',public.v25_format(coalesce(b.table_fee_units,0)),
    'soloProfitLabel',public.v25_format(coalesce(b.solo_profit_units,0)),
    'accountsToday',coalesce(accounts_today,0),
    'openErrors',coalesce(open_errors,0),
    'safeMode',coalesce(safe,false),
    'siteStatus',case when coalesce(safe,false) then 'Modo seguro' else 'Operando' end
  ));
end; $$;

drop function if exists public.app_official03_member_home(text);
create or replace function public.app_official03_member_home(p_token text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare m public.app_members; clan text; ach int;
begin
  m:=public.v25_current(p_token);
  update public.app_members
  set friend_code=coalesce(friend_code,'FR-' || upper(substr(encode(extensions.gen_random_bytes(5),'hex'),1,10)))
  where id=m.id
  returning * into m;

  select c.name into clan
  from public.clan_members_v34 cm join public.clans_v34 c on c.id=cm.clan_id
  where cm.member_id=m.id
  limit 1;

  select count(*) into ach from public.achievements where member_id=m.id;
  return jsonb_build_object('ok',true,'home',jsonb_build_object(
    'balanceLabel',public.v25_format(m.balance_virtual_units),
    'friendCode',m.friend_code,
    'clanName',clan,
    'achievements',coalesce(ach,0)
  ));
end; $$;

drop function if exists public.app_official03_game_rule(text);
create or replace function public.app_official03_game_rule(p_game_key text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare r public.official_game_rules;
begin
  select * into r from public.official_game_rules where game_key=coalesce(nullif(p_game_key,''),'slots');
  return jsonb_build_object('ok',true,'rule',jsonb_build_object(
    'gameName',r.game_name,
    'minBetLabel',public.v25_format(r.min_bet_units),
    'maxBetLabel',public.v25_format(r.max_bet_units),
    'payoutRule',r.payout_rule,
    'bankRule',r.bank_rule,
    'difficulty',r.difficulty
  ));
end; $$;

-- Substitui jogo individual com safe mode, limites, cofre e histórico
drop function if exists public.app_v25_play_game(text,text,text);
create or replace function public.app_v25_play_game(p_token text,p_game_key text,p_amount text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare
  m public.app_members;
  bank public.iris_bank_accounts_mod020;
  flags public.official_system_flags;
  rule public.official_game_rules;
  a numeric;
  win boolean;
  prize numeric:=0;
  reserve numeric;
  available numeric;
  max_single numeric;
  bal numeric;
  tx public.iris_transactions;
  gkey text:=coalesce(nullif(p_game_key,''),'slots');
begin
  m:=public.v25_current(p_token);
  select * into flags from public.official_system_flags where id=1;
  if coalesce(flags.safe_mode,false) then raise exception '%', flags.safe_message; end if;

  select * into rule from public.official_game_rules where game_key=gkey and active=true;
  if rule.game_key is null then raise exception 'Jogo indisponível.'; end if;
  if rule.mode<>'individual' then raise exception 'Este jogo usa modo mesa.'; end if;

  a:=public.v25_parse(p_amount);
  if a<rule.min_bet_units then raise exception 'Aposta abaixo do mínimo.'; end if;
  if a>rule.max_bet_units then raise exception 'Aposta acima do máximo.'; end if;

  select * into bank from public.iris_bank_accounts_mod020 where bank_key='EMSHBY' for update;
  if bank.bank_key is null then raise exception 'Banco EMSHBY não configurado.'; end if;

  reserve:=coalesce(bank.balance_units,0)*(coalesce(bank.reserve_percent,10)/100);
  available:=greatest(coalesce(bank.balance_units,0)-reserve,0);
  max_single:=least(available,coalesce(bank.balance_units,0)*(coalesce(bank.max_single_prize_percent,10)/100));

  if coalesce(bank.balance_units,0)<=0 then raise exception 'Banco EMSHBY temporariamente sem fundos para pagar prêmios.'; end if;
  if m.balance_virtual_units<a then raise exception 'Saldo insuficiente.'; end if;

  prize:=a*2;
  if prize>available or prize>max_single then
    raise exception 'Banco EMSHBY sem saldo disponível para pagar esse prêmio. Tente uma aposta menor.';
  end if;

  win:=random()>=0.52;

  update public.app_members set balance_virtual_units=balance_virtual_units-a,updated_at=now() where id=m.id;

  if win then
    update public.app_members set balance_virtual_units=balance_virtual_units+prize,updated_at=now() where id=m.id;
    update public.iris_bank_accounts_mod020 set balance_units=balance_units-prize,status=case when balance_units-prize<=0 then 'empty' else status end,updated_at=now() where bank_key='EMSHBY';
    insert into public.emshby_ledger(entry_type,direction,amount_units,source,description)
    values('solo_prize','out',prize,gkey,'Prêmio pago em jogo individual');
  else
    prize:=0;
    update public.iris_bank_accounts_mod020 set balance_units=balance_units+a,solo_profit_units=solo_profit_units+a,status='active',updated_at=now() where bank_key='EMSHBY';
    insert into public.emshby_ledger(entry_type,direction,amount_units,source,description)
    values('solo_loss','in',a,gkey,'Perda de jogo individual recebida pelo EMSHBY');
  end if;

  select balance_virtual_units into bal from public.app_members where id=m.id;

  tx:=public.v25_record_tx(
    case when win then 'bet_win' else 'bet_loss' end,
    'completed',
    m.id,
    null,
    m.iris_member_id,
    'EMSHBY',
    a,
    'Jogo individual '||gkey,
    jsonb_build_object('game',gkey,'prize',prize,'bank','EMSHBY','vaultChecked',true)
  );

  insert into public.official_game_history(member_id,game_key,bet_units,prize_units,outcome,tx_code,astral_code,metadata)
  values(m.id,gkey,a,prize,case when win then 'win' else 'loss' end,tx.tx_code,tx.astral_code,jsonb_build_object('balance',bal));

  return jsonb_build_object('ok',true,'result',jsonb_build_object(
    'outcome',case when win then 'win' else 'loss' end,
    'message',case when win then 'Você ganhou e recebeu 2x.' else 'Você perdeu. O valor ficou no Banco EMSHBY.' end,
    'betLabel',public.v25_format(a),
    'prizeLabel',public.v25_format(prize),
    'balanceLabel',public.v25_format(bal),
    'txCode',tx.tx_code,
    'astralCode',tx.astral_code
  ));
end; $$;

drop function if exists public.app_official03_leaderboard(text);
create or replace function public.app_official03_leaderboard(p_token text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare m public.app_members; rows jsonb;
begin
  m:=public.v25_current(p_token);
  select coalesce(jsonb_agg(jsonb_build_object(
    'nick',x.nick,
    'totalWinLabel',public.v25_format(x.total_win),
    'totalBetLabel',public.v25_format(x.total_bet)
  ) order by x.total_win desc),'[]'::jsonb)
  into rows
  from (
    select am.nick, coalesce(sum(gh.prize_units),0) total_win, coalesce(sum(gh.bet_units),0) total_bet
    from public.official_game_history gh
    join public.app_members am on am.id=gh.member_id
    group by am.nick
    order by total_win desc
    limit 50
  ) x;
  return jsonb_build_object('ok',true,'rows',rows);
end; $$;

drop function if exists public.app_official03_events(text);
create or replace function public.app_official03_events(p_token text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare m public.app_members; rows jsonb;
begin
  m:=public.v25_current(p_token);
  select coalesce(jsonb_agg(jsonb_build_object('title',title,'description',description,'kind',kind) order by starts_at desc),'[]'::jsonb)
  into rows from public.official_events where active=true and (ends_at is null or ends_at>now());
  return jsonb_build_object('ok',true,'events',rows);
end; $$;

drop function if exists public.app_official03_inventory(text);
create or replace function public.app_official03_inventory(p_token text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare m public.app_members; rows jsonb;
begin
  m:=public.v25_current(p_token);
  select coalesce(jsonb_agg(jsonb_build_object(
    'itemKey',mi.item_key,
    'name',coalesce(si.name,mi.item_key),
    'category',coalesce(si.category,'item'),
    'rarity',coalesce(si.rarity,'comum')
  ) order by mi.created_at desc),'[]'::jsonb)
  into rows
  from public.member_inventory mi
  left join public.shop_items si on si.item_key=mi.item_key
  where mi.member_id=m.id;
  return jsonb_build_object('ok',true,'items',rows);
end; $$;

drop function if exists public.app_official03_audit(text);
create or replace function public.app_official03_audit(p_token text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare a public.app_members; rows jsonb;
begin
  a:=public.v25_current(p_token);
  if not public.app_official03_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'createdAt',to_char(oa.created_at,'DD/MM HH24:MI'),
    'eventKey',oa.event_key,
    'actor',coalesce(am.nick,'sistema'),
    'message',oa.message
  ) order by oa.created_at desc),'[]'::jsonb)
  into rows
  from public.official_admin_audit oa
  left join public.app_members am on am.id=oa.actor_member_id
  limit 100;
  return jsonb_build_object('ok',true,'rows',rows);
end; $$;

drop function if exists public.app_official03_daily_report(text);
create or replace function public.app_official03_daily_report(p_token text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare a public.app_members; b public.iris_bank_accounts_mod020; deposits_today numeric; withdraw_today numeric; bonus_today numeric; games_today numeric; accounts_today int; msg text;
begin
  a:=public.v25_current(p_token);
  if not public.app_official03_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  select * into b from public.iris_bank_accounts_mod020 where bank_key='EMSHBY';
  select coalesce(sum(amount_units),0) into deposits_today from public.deposit_requests where status='confirmed' and confirmed_at::date=current_date;
  select coalesce(sum(amount_units),0) into withdraw_today from public.withdraw_requests where status='confirmed' and confirmed_at::date=current_date;
  select coalesce(sum(money_units),0) into bonus_today from public.bonus_redemptions_mod030 where redeemed_at::date=current_date;
  select coalesce(sum(case when outcome='loss' then bet_units else 0 end),0) into games_today from public.official_game_history where created_at::date=current_date;
  select count(*) into accounts_today from public.app_members where created_at::date=current_date;

  msg:='BLINDERS CASSINO - RELATÓRIO DIÁRIO '||to_char(current_date,'DD/MM/YYYY')||E'\n\n'
    ||'Cofre EMSHBY: '||public.v25_format(coalesce(b.balance_units,0))||E'\n'
    ||'Depósitos confirmados hoje: '||public.v25_format(coalesce(deposits_today,0))||E'\n'
    ||'Saques pagos hoje: '||public.v25_format(coalesce(withdraw_today,0))||E'\n'
    ||'Bônus distribuídos hoje: '||public.v25_format(coalesce(bonus_today,0))||E'\n'
    ||'Ganhos em jogos individuais hoje: '||public.v25_format(coalesce(games_today,0))||E'\n'
    ||'Comissão total das mesas: '||public.v25_format(coalesce(b.table_fee_units,0))||E'\n'
    ||'Contas criadas hoje: '||coalesce(accounts_today,0);

  return jsonb_build_object('ok',true,'message',msg);
end; $$;

-- Bônus oficial, compatível com Módulo 0.3.0
drop function if exists public.app_mod030_admin_create_bonus(text,text,text,text,int);
create or replace function public.app_mod030_admin_create_bonus(p_token text,p_code text,p_money_amount text default '',p_item_keys text default '',p_max_uses int default 1)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare a public.app_members; c text; money numeric; keys text[];
begin
  a:=public.v25_current(p_token);
  if not public.app_official03_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  c:=upper(regexp_replace(trim(coalesce(p_code,'')),'[^A-Z0-9_\-]','','g'));
  if length(c)<3 then raise exception 'Código muito curto.'; end if;
  money:=public.app_official03_parse_amount(p_money_amount);
  keys:=case when trim(coalesce(p_item_keys,''))='' then array[]::text[] else string_to_array(replace(p_item_keys,' ',''),',') end;
  if money<=0 and array_length(keys,1) is null then raise exception 'Escolha dinheiro, itens ou os dois.'; end if;
  insert into public.bonus_codes_mod030(code,money_units,max_uses,active,created_by) values(c,money,greatest(coalesce(p_max_uses,1),1),true,a.id)
  on conflict(code) do update set money_units=excluded.money_units,max_uses=excluded.max_uses,active=true,created_by=a.id,created_at=now();
  delete from public.bonus_code_items_mod030 where code=c;
  if array_length(keys,1) is not null then insert into public.bonus_code_items_mod030(code,item_key) select c,unnest(keys) on conflict do nothing; end if;
  perform public.app_official03_log(a.id,'bonus_created','Código de bônus criado',jsonb_build_object('code',c,'money',money,'items',keys));
  return jsonb_build_object('ok',true,'code',c,'moneyLabel',public.v25_format(money),'items',coalesce(array_length(keys,1),0));
end; $$;

drop function if exists public.app_mod030_redeem_bonus(text,text);
create or replace function public.app_mod030_redeem_bonus(p_token text,p_code text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare m public.app_members; b public.bonus_codes_mod030; items jsonb; item text;
begin
  m:=public.v25_current(p_token);
  select * into b from public.bonus_codes_mod030 where code=upper(trim(coalesce(p_code,''))) for update;
  if b.code is null then raise exception 'Código não encontrado.'; end if;
  if not b.active then raise exception 'Código inativo.'; end if;
  if b.expires_at is not null and b.expires_at<now() then raise exception 'Código expirado.'; end if;
  if b.used_count>=b.max_uses then raise exception 'Código esgotado.'; end if;
  if b.role_required is not null and b.role_required<>m.role then raise exception 'Código não disponível para seu cargo.'; end if;
  if b.new_members_only and m.created_at::date < current_date then raise exception 'Código apenas para membros novos.'; end if;
  if exists(select 1 from public.bonus_redemptions_mod030 where code=b.code and member_id=m.id) then raise exception 'Você já resgatou esse código.'; end if;

  if b.money_units>0 then
    update public.app_members set balance_virtual_units=balance_virtual_units+b.money_units,updated_at=now() where id=m.id;
    update public.iris_bank_accounts_mod020 set bonus_distributed_units=bonus_distributed_units+b.money_units where bank_key='EMSHBY';
  end if;

  select coalesce(jsonb_agg(item_key),'[]'::jsonb) into items from public.bonus_code_items_mod030 where code=b.code;
  for item in select item_key from public.bonus_code_items_mod030 where code=b.code loop
    insert into public.member_inventory(member_id,item_key,source) values(m.id,item,'bonus:'||b.code);
  end loop;
  insert into public.bonus_redemptions_mod030(code,member_id,money_units,items) values(b.code,m.id,b.money_units,items);
  update public.bonus_codes_mod030 set used_count=used_count+1 where code=b.code;
  return jsonb_build_object('ok',true,'reward',jsonb_build_object('moneyLabel',public.v25_format(b.money_units),'items',items));
end; $$;

-- rotas
insert into public.app_routes(route_key,route_title,route_path,route_group,requires_role,icon,display_order,active,updated_at)
values
('member_status_official','Meu status','/member/status.html','member','user','status',16,true,now()),
('events_official','Eventos','/events/index.html','member','user','shop',17,true,now()),
('leaderboard_official','Ranking','/leaderboard/index.html','member','user','achievements',18,true,now()),
('inventory_official','Inventário','/member/inventory.html','member','user','shop',19,true,now()),
('official_dashboard_admin','Painel oficial','/owner/official-dashboard.html','admin','admin','status',31,true,now()),
('official_backups_admin','Backups','/owner/backups.html','admin','admin','settings',32,true,now()),
('official_health_admin','Saúde','/owner/health.html','admin','admin','status',33,true,now()),
('official_reports_admin','Relatórios','/owner/reports-center.html','admin','admin','history',34,true,now()),
('official_audit_admin','Auditoria','/owner/audit.html','admin','admin','logs',35,true,now())
on conflict(route_key) do update set route_title=excluded.route_title,route_path=excluded.route_path,route_group=excluded.route_group,requires_role=excluded.requires_role,icon=excluded.icon,display_order=excluded.display_order,active=true,updated_at=now();

grant execute on function public.app_official03_create_backup(text,text) to anon, authenticated;
grant execute on function public.app_official03_toggle_safe_mode(text,boolean) to anon, authenticated;
grant execute on function public.app_official03_health(text) to anon, authenticated;
grant execute on function public.app_official03_admin_overview(text) to anon, authenticated;
grant execute on function public.app_official03_member_home(text) to anon, authenticated;
grant execute on function public.app_official03_game_rule(text) to anon, authenticated;
grant execute on function public.app_v25_play_game(text,text,text) to anon, authenticated;
grant execute on function public.app_official03_leaderboard(text) to anon, authenticated;
grant execute on function public.app_official03_events(text) to anon, authenticated;
grant execute on function public.app_official03_inventory(text) to anon, authenticated;
grant execute on function public.app_official03_audit(text) to anon, authenticated;
grant execute on function public.app_official03_daily_report(text) to anon, authenticated;
grant execute on function public.app_mod030_admin_create_bonus(text,text,text,text,int) to anon, authenticated;
grant execute on function public.app_mod030_redeem_bonus(text,text) to anon, authenticated;

select 'BLINDERS_0_3_OFICIAL_ESTAVEL_OK' as status;


-- ============================================================
-- ZIP: blinders-cassino-0-3-1-engine-control-sql.zip
-- FILE: BLINDERS_0_3_1_ENGINE_CONTROL.sql
-- ============================================================

-- ============================================================
-- BLINDERS CASSINO — 0.3.1
-- Engine real nos jogos + núcleo oculto de autogerenciamento + controle Supabase.
-- Rode depois da 0.3 oficial estável.
-- Resultado esperado: BLINDERS_0_3_1_ENGINE_CONTROL_OK
-- ============================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.malena_events_hidden (
  id uuid primary key default extensions.gen_random_uuid(),
  event_type text not null default 'diagnostic',
  category text not null default 'system',
  severity text not null default 'info',
  token_present boolean not null default false,
  member_id uuid references public.app_members(id) on delete set null,
  route text,
  message text,
  metadata jsonb not null default '{}',
  status text not null default 'open',
  created_at timestamptz default now(),
  resolved_at timestamptz
);

create table if not exists public.malena_diagnostics_hidden (
  id uuid primary key default extensions.gen_random_uuid(),
  diagnostic_key text not null,
  ok boolean not null default true,
  issue text,
  fix_hint text,
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

create table if not exists public.official_admin_audit (
  id uuid primary key default extensions.gen_random_uuid(),
  actor_member_id uuid references public.app_members(id) on delete set null,
  event_key text not null,
  message text,
  metadata jsonb not null default '{}',
  created_at timestamptz default now()
);

create table if not exists public.official_system_flags (
  id int primary key default 1,
  safe_mode boolean not null default false,
  safe_message text not null default 'Modo seguro ativo. Jogos temporariamente pausados.',
  pwa_enabled boolean not null default true,
  updated_by uuid references public.app_members(id) on delete set null,
  updated_at timestamptz default now()
);
insert into public.official_system_flags(id) values(1) on conflict(id) do nothing;

create table if not exists public.official_stable_backups (
  id uuid primary key default extensions.gen_random_uuid(),
  backup_code text unique not null default ('BKP-' || upper(substr(encode(extensions.gen_random_bytes(5),'hex'),1,10))),
  label text not null default 'Backup estável',
  app_version text not null default '0.3 oficial',
  metadata jsonb not null default '{}',
  created_by uuid references public.app_members(id) on delete set null,
  created_at timestamptz default now()
);

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
alter table public.iris_bank_accounts_mod020 add column if not exists withdraw_paid_units numeric(40,2) not null default 0;
alter table public.iris_bank_accounts_mod020 add column if not exists bonus_distributed_units numeric(40,2) not null default 0;
alter table public.iris_bank_accounts_mod020 add column if not exists reserve_percent numeric(8,2) not null default 10;
alter table public.iris_bank_accounts_mod020 add column if not exists max_single_prize_percent numeric(8,2) not null default 10;
alter table public.iris_bank_accounts_mod020 add column if not exists status text not null default 'active';
insert into public.iris_bank_accounts_mod020(bank_key,display_name,iris_id) values('EMSHBY','Banco EMSHBY','EMSHBY') on conflict(bank_key) do nothing;

alter table public.app_members add column if not exists friend_code text;

insert into public.app_routes(route_key,route_title,route_path,route_group,requires_role,icon,display_order,active,updated_at)
values('supabase_control_031','Controle Supabase','/owner/supabase-control.html','admin','admin','settings',36,true,now())
on conflict(route_key) do update set route_title=excluded.route_title,route_path=excluded.route_path,route_group=excluded.route_group,requires_role=excluded.requires_role,icon=excluded.icon,display_order=excluded.display_order,active=true,updated_at=now();

drop function if exists public.app_malena_current_member(text);
create or replace function public.app_malena_current_member(p_token text) returns uuid language plpgsql security definer set search_path=public,extensions as $$
declare m public.app_members;
begin
  if coalesce(p_token,'')='' then return null; end if;
  begin m:=public.v25_current(p_token); return m.id; exception when others then return null; end;
end; $$;

drop function if exists public.app_malena_report_error(text,text,text,text,jsonb);
create or replace function public.app_malena_report_error(p_token text,p_category text,p_message text,p_route text default '',p_metadata jsonb default '{}') returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare mid uuid;
begin
  mid:=public.app_malena_current_member(p_token);
  insert into public.malena_events_hidden(event_type,category,severity,token_present,member_id,route,message,metadata) values('error',coalesce(p_category,'system'),'warning',coalesce(p_token,'')<>'',mid,p_route,p_message,coalesce(p_metadata,'{}'::jsonb));
  insert into public.official_error_logs(category,severity,member_id,route,message,metadata,status) values(coalesce(p_category,'system'),'warning',mid,p_route,p_message,coalesce(p_metadata,'{}'::jsonb),'open');
  return jsonb_build_object('ok',true);
end; $$;

drop function if exists public.app_malena_ping(text,text,text,int,int);
create or replace function public.app_malena_ping(p_token text,p_route text,p_user_agent text,p_width int,p_height int) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare mid uuid;
begin
  mid:=public.app_malena_current_member(p_token);
  insert into public.malena_events_hidden(event_type,category,severity,token_present,member_id,route,message,metadata,status) values('ping','page','info',coalesce(p_token,'')<>'',mid,p_route,'page_loaded',jsonb_build_object('ua',p_user_agent,'w',p_width,'h',p_height),'closed');
  return jsonb_build_object('ok',true);
end; $$;

drop function if exists public.app_malena_diagnose_internal();
create or replace function public.app_malena_diagnose_internal() returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare result jsonb;
begin
  result:=jsonb_build_object(
    'tables',jsonb_build_object('app_members',to_regclass('public.app_members') is not null,'iris_transactions',to_regclass('public.iris_transactions') is not null,'emshby',exists(select 1 from public.iris_bank_accounts_mod020 where bank_key='EMSHBY'),'bonus_codes',to_regclass('public.bonus_codes_mod030') is not null,'chat',to_regclass('public.global_chat_messages_mod020') is not null,'clans',to_regclass('public.clans_v34') is not null),
    'functions',jsonb_build_object('login',to_regprocedure('public.app_login(text,text,text,text)') is not null,'play_game',to_regprocedure('public.app_v25_play_game(text,text,text)') is not null,'official_overview',to_regprocedure('public.app_official03_admin_overview(text)') is not null),
    'safeMode',(select safe_mode from public.official_system_flags where id=1),
    'openErrors',(select count(*) from public.official_error_logs where status='open'),
    'checkedAt',now()
  );
  insert into public.malena_diagnostics_hidden(diagnostic_key,ok,issue,fix_hint,metadata) values('full_diagnostic',true,null,'Sem ação automática necessária.',result);
  return result;
end; $$;

drop function if exists public.app_official031_is_admin(public.app_members);
create or replace function public.app_official031_is_admin(m public.app_members) returns boolean language sql stable as $$ select coalesce(m.role,'user') in ('admin','owner') $$;

drop function if exists public.app_official031_supabase_status(text);
create or replace function public.app_official031_supabase_status(p_token text) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare a public.app_members; diag jsonb;
begin
  a:=public.v25_current(p_token);
  if not public.app_official031_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  diag:=public.app_malena_diagnose_internal();
  return jsonb_build_object('ok',true,'status','online','diagnostic',diag,'recommendations',jsonb_build_array(jsonb_build_object('issue','Erros abertos','fix','Limpe erros depois de corrigir a causa.'),jsonb_build_object('issue','Cofre zerado','fix','Atualize o cofre EMSHBY antes de liberar jogos.'),jsonb_build_object('issue','Rotas ausentes','fix','Execute reparar rotas.'),jsonb_build_object('issue','IDs antigos sem código','fix','Execute reparar IDs únicos.')));
end; $$;

drop function if exists public.app_official031_supabase_action(text,text);
create or replace function public.app_official031_supabase_action(p_token text,p_action text) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare a public.app_members; action text:=lower(trim(coalesce(p_action,''))); code text; affected int:=0; diag jsonb;
begin
  a:=public.v25_current(p_token);
  if not public.app_official031_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;
  if action='diagnose' then
    diag:=public.app_malena_diagnose_internal(); return jsonb_build_object('ok',true,'action',action,'diagnostic',diag);
  elsif action='create_backup' then
    insert into public.official_stable_backups(label,created_by,metadata) values('Backup Supabase Control',a.id,jsonb_build_object('source','supabase_control')) returning backup_code into code;
    insert into public.official_admin_audit(actor_member_id,event_key,message,metadata) values(a.id,'backup_created','Backup criado pelo controle Supabase',jsonb_build_object('backupCode',code));
    return jsonb_build_object('ok',true,'action',action,'backupCode',code);
  elsif action='enable_safe_mode' then
    update public.official_system_flags set safe_mode=true,updated_by=a.id,updated_at=now() where id=1; return jsonb_build_object('ok',true,'action',action,'safeMode',true);
  elsif action='disable_safe_mode' then
    update public.official_system_flags set safe_mode=false,updated_by=a.id,updated_at=now() where id=1; return jsonb_build_object('ok',true,'action',action,'safeMode',false);
  elsif action='repair_emshby' then
    insert into public.iris_bank_accounts_mod020(bank_key,display_name,iris_id,status) values('EMSHBY','Banco EMSHBY','EMSHBY','active') on conflict(bank_key) do update set display_name='Banco EMSHBY', iris_id='EMSHBY', updated_at=now(); return jsonb_build_object('ok',true,'action',action,'message','Banco EMSHBY verificado/reparado.');
  elsif action='repair_friend_codes' then
    update public.app_members set friend_code='FR-' || upper(substr(encode(extensions.gen_random_bytes(5),'hex'),1,10)) where friend_code is null or trim(friend_code)=''; get diagnostics affected = row_count; return jsonb_build_object('ok',true,'action',action,'updated',affected);
  elsif action='repair_routes' then
    insert into public.app_routes(route_key,route_title,route_path,route_group,requires_role,icon,display_order,active,updated_at) values('supabase_control_031','Controle Supabase','/owner/supabase-control.html','admin','admin','settings',36,true,now()),('official_dashboard_admin','Painel oficial','/owner/official-dashboard.html','admin','admin','status',31,true,now()),('official_health_admin','Saúde','/owner/health.html','admin','admin','status',33,true,now()) on conflict(route_key) do update set active=true,updated_at=now(); return jsonb_build_object('ok',true,'action',action,'message','Rotas oficiais verificadas/reparadas.');
  elsif action='clear_open_errors' then
    update public.official_error_logs set status='closed' where status='open'; get diagnostics affected = row_count; update public.malena_events_hidden set status='closed', resolved_at=now() where status='open'; return jsonb_build_object('ok',true,'action',action,'closedErrors',affected);
  elsif action='clear_old_sessions' then
    delete from public.app_member_sessions where expires_at < now(); get diagnostics affected = row_count; return jsonb_build_object('ok',true,'action',action,'deletedSessions',affected);
  else
    raise exception 'Ação inválida.';
  end if;
end; $$;

grant execute on function public.app_malena_current_member(text) to anon, authenticated;
grant execute on function public.app_malena_report_error(text,text,text,text,jsonb) to anon, authenticated;
grant execute on function public.app_malena_ping(text,text,text,int,int) to anon, authenticated;
grant execute on function public.app_malena_diagnose_internal() to anon, authenticated;
grant execute on function public.app_official031_supabase_status(text) to anon, authenticated;
grant execute on function public.app_official031_supabase_action(text,text) to anon, authenticated;

select 'BLINDERS_0_3_1_ENGINE_CONTROL_OK' as status;


-- ============================================================
-- ZIP: blinders-cassino-0-3-2-jogos-reais-sql.zip
-- FILE: BLINDERS_0_3_2_JOGOS_REAIS.sql
-- ============================================================

-- ============================================================
-- BLINDERS CASSINO — 0.3.2 JOGOS REAIS
-- Jogos com partida real no navegador + validação e liquidação no Supabase.
-- Rode depois da 0.3.1.
-- Resultado esperado: BLINDERS_0_3_2_JOGOS_REAIS_OK
-- ============================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.real_game_sessions_032 (
  id uuid primary key default extensions.gen_random_uuid(),
  member_id uuid references public.app_members(id) on delete set null,
  game_key text not null,
  bet_units numeric(40,2) not null default 0,
  status text not null default 'started',
  created_at timestamptz default now(),
  finished_at timestamptz,
  outcome text,
  payout_mult numeric(12,4) not null default 0,
  prize_units numeric(40,2) not null default 0,
  tx_code text,
  astral_code text,
  details jsonb not null default '{}'
);

create table if not exists public.official_game_rules (
  game_key text primary key,
  game_name text not null,
  mode text not null default 'individual',
  min_bet_units numeric(40,2) not null default 1000000000,
  max_bet_units numeric(40,2) not null default 1000000000000,
  difficulty text not null default 'normal',
  payout_rule text not null,
  bank_rule text not null,
  max_players int not null default 1,
  requires_master boolean not null default false,
  quick_play boolean not null default true,
  active boolean not null default true,
  updated_at timestamptz default now()
);

insert into public.official_game_rules(game_key,game_name,mode,min_bet_units,max_bet_units,difficulty,payout_rule,bank_rule,max_players,requires_master,quick_play)
values
('blackjack','Blackjack','individual',1000000000,1000000000000,'normal','Jogo real com pedir carta/parar. Vitória paga conforme resultado.','Prêmios dependem do cofre EMSHBY.',1,false,true),
('bingo','Bingo','individual',1000000000,1000000000000,'normal','Cartela real: complete linha, coluna ou diagonal em até 18 bolas.','Prêmios dependem do cofre EMSHBY.',1,false,true),
('dados','Dados','individual',1000000000,1000000000000,'normal','Role dois dados. Soma 7 ou mais vence.','Prêmios dependem do cofre EMSHBY.',1,false,true),
('roleta','Roleta','individual',1000000000,1000000000000,'normal','Escolha cor/paridade/zero e gire a roleta.','Prêmios dependem do cofre EMSHBY.',1,false,true),
('slots','Slots','individual',1000000000,1000000000000,'normal','Gire três rolos. Três símbolos iguais vencem.','Prêmios dependem do cofre EMSHBY.',1,false,true),
('crash','Crash','individual',1000000000,1000000000000,'normal','Retire antes de crashar. Multiplicador define prêmio.','Prêmios dependem do cofre EMSHBY.',1,false,true),
('memoria','Memória','individual',1000000000,1000000000000,'normal','Encontre todos os pares dentro do limite de jogadas.','Prêmios dependem do cofre EMSHBY.',1,false,true),
('mines','Mines','individual',1000000000,1000000000000,'normal','Abra casas seguras sem achar bomba.','Prêmios dependem do cofre EMSHBY.',1,false,true),
('plinko','Plinko','individual',1000000000,1000000000000,'normal','Solte a bola. Caminho final define vitória.','Prêmios dependem do cofre EMSHBY.',1,false,true),
('coinflip','Coin Flip','individual',1000000000,1000000000000,'normal','Escolha cara ou coroa.','Prêmios dependem do cofre EMSHBY.',1,false,true),
('baccarat','Baccarat','individual',1000000000,1000000000000,'normal','Aposte em jogador ou banco. Maior ponto vence.','Prêmios dependem do cofre EMSHBY.',1,false,true)
on conflict(game_key) do update set
  game_name=excluded.game_name,
  mode=excluded.mode,
  payout_rule=excluded.payout_rule,
  bank_rule=excluded.bank_rule,
  active=true,
  updated_at=now();

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

drop function if exists public.app_real032_validate_start(text,text,text);
create or replace function public.app_real032_validate_start(p_token text,p_game_key text,p_amount text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  m public.app_members;
  rule public.official_game_rules;
  bank public.iris_bank_accounts_mod020;
  a numeric;
  reserve numeric;
  available numeric;
  max_single numeric;
begin
  m:=public.v25_current(p_token);
  a:=public.v25_parse(p_amount);

  select * into rule from public.official_game_rules where game_key=coalesce(nullif(p_game_key,''),'slots') and active=true;
  if rule.game_key is null then raise exception 'Jogo indisponível.'; end if;

  if a<rule.min_bet_units then raise exception 'Aposta abaixo do mínimo.'; end if;
  if a>rule.max_bet_units then raise exception 'Aposta acima do máximo.'; end if;
  if m.balance_virtual_units<a then raise exception 'Saldo insuficiente.'; end if;

  select * into bank from public.iris_bank_accounts_mod020 where bank_key='EMSHBY';
  if bank.bank_key is null then raise exception 'Banco EMSHBY não configurado.'; end if;
  if coalesce(bank.balance_units,0)<=0 then raise exception 'Banco EMSHBY sem fundos para prêmios.'; end if;

  reserve:=coalesce(bank.balance_units,0)*(coalesce(bank.reserve_percent,10)/100);
  available:=greatest(coalesce(bank.balance_units,0)-reserve,0);
  max_single:=least(available,coalesce(bank.balance_units,0)*(coalesce(bank.max_single_prize_percent,10)/100));

  if (a*3)>available or (a*3)>max_single then
    raise exception 'Cofre EMSHBY não suporta o prêmio máximo desse jogo. Use aposta menor.';
  end if;

  return jsonb_build_object('ok',true,'game',rule.game_name,'betLabel',public.v25_format(a),'maxPrizeLabel',public.v25_format(max_single));
end;
$$;

drop function if exists public.app_real032_settle_game(text,text,text,text,numeric,jsonb);
create or replace function public.app_real032_settle_game(
  p_token text,
  p_game_key text,
  p_amount text,
  p_outcome text,
  p_payout_mult numeric default 0,
  p_details jsonb default '{}'
)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  m public.app_members;
  rule public.official_game_rules;
  bank public.iris_bank_accounts_mod020;
  a numeric;
  mult numeric;
  prize numeric;
  reserve numeric;
  available numeric;
  max_single numeric;
  tx public.iris_transactions;
  bal numeric;
begin
  m:=public.v25_current(p_token);
  a:=public.v25_parse(p_amount);
  mult:=least(greatest(coalesce(p_payout_mult,0),0),14);
  prize:=case when p_outcome='win' then round(a*mult,2) when p_outcome='push' then a else 0 end;

  select * into rule from public.official_game_rules where game_key=coalesce(nullif(p_game_key,''),'slots') and active=true;
  if rule.game_key is null then raise exception 'Jogo indisponível.'; end if;

  if a<rule.min_bet_units then raise exception 'Aposta abaixo do mínimo.'; end if;
  if a>rule.max_bet_units then raise exception 'Aposta acima do máximo.'; end if;
  if m.balance_virtual_units<a then raise exception 'Saldo insuficiente.'; end if;

  select * into bank from public.iris_bank_accounts_mod020 where bank_key='EMSHBY' for update;
  if bank.bank_key is null then raise exception 'Banco EMSHBY não configurado.'; end if;

  reserve:=coalesce(bank.balance_units,0)*(coalesce(bank.reserve_percent,10)/100);
  available:=greatest(coalesce(bank.balance_units,0)-reserve,0);
  max_single:=least(available,coalesce(bank.balance_units,0)*(coalesce(bank.max_single_prize_percent,10)/100));

  if prize>0 and (coalesce(bank.balance_units,0)<=0 or prize>available or prize>max_single) then
    raise exception 'Banco EMSHBY sem saldo disponível para pagar esse prêmio.';
  end if;

  update public.app_members set balance_virtual_units=balance_virtual_units-a,updated_at=now() where id=m.id;

  if prize>0 then
    update public.app_members set balance_virtual_units=balance_virtual_units+prize,updated_at=now() where id=m.id;
    if p_outcome='win' then
      update public.iris_bank_accounts_mod020
      set balance_units=balance_units-prize,
          status=case when balance_units-prize<=0 then 'empty' else status end,
          updated_at=now()
      where bank_key='EMSHBY';
    end if;
  else
    update public.iris_bank_accounts_mod020
    set balance_units=balance_units+a,
        solo_profit_units=solo_profit_units+a,
        status='active',
        updated_at=now()
    where bank_key='EMSHBY';
  end if;

  select balance_virtual_units into bal from public.app_members where id=m.id;

  tx:=public.v25_record_tx(
    case when p_outcome='win' then 'real_game_win' when p_outcome='push' then 'real_game_push' else 'real_game_loss' end,
    'completed',
    m.id,
    null,
    m.iris_member_id,
    'EMSHBY',
    a,
    'Jogo real '||rule.game_name,
    jsonb_build_object('game',rule.game_key,'outcome',p_outcome,'mult',mult,'prize',prize,'details',coalesce(p_details,'{}'::jsonb))
  );

  insert into public.real_game_sessions_032(member_id,game_key,bet_units,status,finished_at,outcome,payout_mult,prize_units,tx_code,astral_code,details)
  values(m.id,rule.game_key,a,'finished',now(),p_outcome,mult,prize,tx.tx_code,tx.astral_code,coalesce(p_details,'{}'::jsonb));

  return jsonb_build_object('ok',true,'result',jsonb_build_object(
    'outcome',p_outcome,
    'message',case when p_outcome='win' then 'Você venceu a partida real.' when p_outcome='push' then 'Empate. Parte do valor retornou.' else 'Você perdeu a partida real.' end,
    'betLabel',public.v25_format(a),
    'prizeLabel',public.v25_format(prize),
    'balanceLabel',public.v25_format(bal),
    'txCode',tx.tx_code,
    'astralCode',tx.astral_code
  ));
end;
$$;

grant execute on function public.app_real032_validate_start(text,text,text) to anon, authenticated;
grant execute on function public.app_real032_settle_game(text,text,text,text,numeric,jsonb) to anon, authenticated;

select 'BLINDERS_0_3_2_JOGOS_REAIS_OK' as status;


-- ============================================================
-- ZIP: blinders-cassino-0-3-3-limites-zarcovi-sql.zip
-- FILE: BLINDERS_0_3_3_LIMITES_ZARCOVI.sql
-- ============================================================

-- ============================================================
-- BLINDERS CASSINO — 0.3.3 LIMITES + IMPORT ZARCOVI
-- Aposta mínima: 1500B / 1,5T
-- Aposta máxima: 3T
-- Rode depois da 0.3.2.
-- Resultado esperado: BLINDERS_0_3_3_LIMITES_ZARCOVI_OK
-- ============================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- 1,5T = 1.500.000.000.000 unidades
-- 3T   = 3.000.000.000.000 unidades
do $$
begin
  if to_regclass('public.official_game_rules') is not null then
    update public.official_game_rules
    set min_bet_units = 1500000000000,
        max_bet_units = 3000000000000,
        updated_at = now()
    where active = true;
  end if;

  if to_regclass('public.game_rules_mod020') is not null then
    update public.game_rules_mod020
    set updated_at = now()
    where active = true;
  end if;
end $$;

create table if not exists public.zarcovi_import_accounts (
  id uuid primary key default extensions.gen_random_uuid(),
  source_sheet text not null default 'Zarcovi banco 01',
  row_ref text,
  account_type text not null default 'Conta',
  vila text,
  conta text,
  level int,
  ryos_visivel numeric(40,2) default 0,
  salario numeric(40,2) default 0,
  cargos text,
  vontade_fogo int default 0,
  vontade_pedra int default 0,
  personagem text,
  tesouro numeric(40,2) default 0,
  status text not null default 'importado',
  metadata jsonb not null default '{}',
  created_at timestamptz default now()
);

create index if not exists idx_zarcovi_import_accounts_conta on public.zarcovi_import_accounts(conta);
create index if not exists idx_zarcovi_import_accounts_vila on public.zarcovi_import_accounts(vila);

create table if not exists public.zarcovi_import_batches (
  id uuid primary key default extensions.gen_random_uuid(),
  batch_name text not null,
  source_url text,
  total_rows int not null default 0,
  imported_by uuid references public.app_members(id) on delete set null,
  created_at timestamptz default now()
);

insert into public.app_routes(route_key, route_title, route_path, route_group, requires_role, icon, display_order, active, updated_at)
values
('zarcovi_import_033','Importar Zarcovi','/owner/zarcovi-import.html','admin','admin','history',37,true,now())
on conflict(route_key) do update set
  route_title=excluded.route_title,
  route_path=excluded.route_path,
  route_group=excluded.route_group,
  requires_role=excluded.requires_role,
  icon=excluded.icon,
  display_order=excluded.display_order,
  active=true,
  updated_at=now();

drop function if exists public.app_033_bet_limits();
create or replace function public.app_033_bet_limits()
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'ok', true,
    'minLabel', '1500B / 1,5T',
    'maxLabel', '3T',
    'minUnits', 1500000000000,
    'maxUnits', 3000000000000
  )
$$;

grant execute on function public.app_033_bet_limits() to anon, authenticated;

select 'BLINDERS_0_3_3_LIMITES_ZARCOVI_OK' as status;


-- ============================================================
-- ZIP: blinders-cassino-0-3-4-zarcovi-live-sync-sql.zip
-- FILE: BLINDERS_0_3_4_ZARCOVI_LIVE_SYNC.sql
-- ============================================================

-- ============================================================
-- BLINDERS CASSINO — 0.3.4 ZARCOVI LIVE SYNC
-- Saldos Zarcovi silenciosos + EMSHBY sincronizado + limites 1500B/3T.
-- Rode depois da 0.3.3.
-- Resultado esperado: BLINDERS_0_3_4_ZARCOVI_LIVE_SYNC_OK
-- ============================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- Limites oficiais: mínimo 1500B = 1,5T / máximo 3T
do $$
begin
  if to_regclass('public.official_game_rules') is not null then
    update public.official_game_rules
    set min_bet_units = 1500000000000,
        max_bet_units = 3000000000000,
        updated_at = now()
    where active = true;
  end if;
end $$;

create table if not exists public.zarcovi_live_sources (
  source_key text primary key default 'banco01',
  source_name text not null default 'Zarcovi banco 01',
  source_url text,
  enabled boolean not null default true,
  last_sync_at timestamptz,
  last_status text,
  last_count int not null default 0,
  updated_by uuid references public.app_members(id) on delete set null,
  updated_at timestamptz default now()
);

insert into public.zarcovi_live_sources(source_key,source_name,source_url,last_status)
values(
  'banco01',
  'Zarcovi banco 01',
  'https://docs.google.com/spreadsheets/d/1cUVGRl63tyJvxRK-9nlAhnLBdgunEy9OU-sKYNIx83Y/gviz/tq?tqx=out:csv&gid=0',
  'aguardando sincronização'
)
on conflict(source_key) do nothing;

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

create index if not exists idx_zarcovi_live_accounts_vila on public.zarcovi_live_accounts(vila);
create index if not exists idx_zarcovi_live_accounts_synced on public.zarcovi_live_accounts(synced_at desc);

-- Compatibilidade com banco EMSHBY
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

alter table public.app_members add column if not exists zarcovi_account text;
alter table public.app_members add column if not exists friend_code text;

drop function if exists public.app_zarcovi_live_is_admin(public.app_members);
create or replace function public.app_zarcovi_live_is_admin(m public.app_members)
returns boolean language sql stable as $$
  select coalesce(m.role,'user') in ('admin','owner')
$$;

drop function if exists public.app_zarcovi_live_format_b(numeric);
create or replace function public.app_zarcovi_live_format_b(p_b numeric)
returns text
language plpgsql
immutable
as $$
begin
  if abs(coalesce(p_b,0)) >= 1000 then
    return trim(to_char(coalesce(p_b,0)/1000,'FM999999999999990D00')) || 'T';
  end if;
  return trim(to_char(coalesce(p_b,0),'FM999999999999990D00')) || 'B';
end;
$$;

drop function if exists public.app_zarcovi_live_set_source(text,text);
create or replace function public.app_zarcovi_live_set_source(p_token text,p_source_url text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare a public.app_members;
begin
  a:=public.v25_current(p_token);
  if not public.app_zarcovi_live_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;

  insert into public.zarcovi_live_sources(source_key,source_name,source_url,updated_by,updated_at,last_status)
  values('banco01','Zarcovi banco 01',p_source_url,a.id,now(),'fonte atualizada')
  on conflict(source_key) do update set
    source_url=excluded.source_url,
    updated_by=a.id,
    updated_at=now(),
    last_status='fonte atualizada';

  return jsonb_build_object('ok',true,'sourceUrl',p_source_url);
end;
$$;

drop function if exists public.app_zarcovi_live_upsert_accounts(text,text,text,jsonb);
create or replace function public.app_zarcovi_live_upsert_accounts(
  p_token text,
  p_source_key text,
  p_source_url text,
  p_accounts jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  a public.app_members;
  imported int:=0;
  em public.zarcovi_live_accounts;
begin
  a:=public.v25_current(p_token);
  if not public.app_zarcovi_live_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;

  insert into public.zarcovi_live_accounts(
    account_code, source_key, source_row, kind, vila, level_num,
    ryos_visible_b, ryos_units, salario_b, salario_units, cargos,
    vontade_fogo, vontade_pedra, personagem, tesouro_b, tesouro_units,
    raw_data, synced_at, updated_at
  )
  select
    upper(trim(x.conta)),
    coalesce(nullif(p_source_key,''),'banco01'),
    x."sourceRow",
    x.kind,
    x.vila,
    coalesce(x.level,0),
    coalesce(x."ryosB",0),
    coalesce(x."ryosB",0) * 1000000000,
    coalesce(x."salarioB",0),
    coalesce(x."salarioB",0) * 1000000000,
    x.cargos,
    coalesce(x.fogo,0),
    coalesce(x.pedra,0),
    x.personagem,
    coalesce(x."tesouroB",0),
    coalesce(x."tesouroB",0) * 1000000000,
    to_jsonb(x),
    now(),
    now()
  from jsonb_to_recordset(coalesce(p_accounts,'[]'::jsonb)) as x(
    "sourceRow" int,
    kind text,
    vila text,
    conta text,
    level numeric,
    "ryosB" numeric,
    "salarioB" numeric,
    cargos text,
    fogo numeric,
    pedra numeric,
    personagem text,
    "tesouroB" numeric,
    raw jsonb
  )
  where coalesce(trim(x.conta),'') <> ''
  on conflict(account_code) do update set
    source_key=excluded.source_key,
    source_row=excluded.source_row,
    kind=excluded.kind,
    vila=excluded.vila,
    level_num=excluded.level_num,
    ryos_visible_b=excluded.ryos_visible_b,
    ryos_units=excluded.ryos_units,
    salario_b=excluded.salario_b,
    salario_units=excluded.salario_units,
    cargos=excluded.cargos,
    vontade_fogo=excluded.vontade_fogo,
    vontade_pedra=excluded.vontade_pedra,
    personagem=excluded.personagem,
    tesouro_b=excluded.tesouro_b,
    tesouro_units=excluded.tesouro_units,
    raw_data=excluded.raw_data,
    synced_at=now(),
    updated_at=now();

  get diagnostics imported = row_count;

  update public.zarcovi_live_sources
  set source_url=coalesce(nullif(p_source_url,''),source_url),
      last_sync_at=now(),
      last_status='sincronizado',
      last_count=last_count + imported,
      updated_by=a.id,
      updated_at=now()
  where source_key=coalesce(nullif(p_source_key,''),'banco01');

  select * into em from public.zarcovi_live_accounts where account_code='EMSHBY';

  if em.account_code is not null then
    update public.iris_bank_accounts_mod020
    set balance_units=em.ryos_units,
        status=case when em.ryos_units<=0 then 'empty' else 'active' end,
        updated_at=now()
    where bank_key='EMSHBY';
  end if;

  return jsonb_build_object(
    'ok',true,
    'imported',imported,
    'emshby',case when em.account_code is null then null else jsonb_build_object(
      'accountCode',em.account_code,
      'ryosB',em.ryos_visible_b,
      'ryosLabel',public.app_zarcovi_live_format_b(em.ryos_visible_b),
      'tesouroB',em.tesouro_b,
      'syncedAt',em.synced_at
    ) end
  );
end;
$$;

drop function if exists public.app_zarcovi_live_apply_emshby(text);
create or replace function public.app_zarcovi_live_apply_emshby(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare a public.app_members; em public.zarcovi_live_accounts;
begin
  a:=public.v25_current(p_token);
  if not public.app_zarcovi_live_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;

  select * into em from public.zarcovi_live_accounts where account_code='EMSHBY';
  if em.account_code is null then raise exception 'EMSHBY ainda não foi encontrado na planilha sincronizada.'; end if;

  update public.iris_bank_accounts_mod020
  set balance_units=em.ryos_units,
      status=case when em.ryos_units<=0 then 'empty' else 'active' end,
      updated_at=now()
  where bank_key='EMSHBY';

  return jsonb_build_object(
    'ok',true,
    'emshby',jsonb_build_object(
      'accountCode',em.account_code,
      'ryosLabel',public.app_zarcovi_live_format_b(em.ryos_visible_b),
      'ryosUnits',em.ryos_units,
      'tesouroLabel',public.app_zarcovi_live_format_b(em.tesouro_b),
      'syncedAt',em.synced_at
    )
  );
end;
$$;

drop function if exists public.app_zarcovi_live_member_balance(text);
create or replace function public.app_zarcovi_live_member_balance(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  m public.app_members;
  z public.zarcovi_live_accounts;
  em public.zarcovi_live_accounts;
  acct text;
begin
  m:=public.v25_current(p_token);
  acct:=upper(trim(coalesce(m.zarcovi_account,m.nick,'')));

  select * into z from public.zarcovi_live_accounts where account_code=acct;
  select * into em from public.zarcovi_live_accounts where account_code='EMSHBY';

  return jsonb_build_object(
    'ok',true,
    'account',case when z.account_code is null then null else jsonb_build_object(
      'accountCode',z.account_code,
      'vila',z.vila,
      'level',z.level_num,
      'ryosB',z.ryos_visible_b,
      'ryosLabel',public.app_zarcovi_live_format_b(z.ryos_visible_b),
      'salarioLabel',public.app_zarcovi_live_format_b(z.salario_b),
      'cargos',z.cargos,
      'personagem',z.personagem,
      'tesouroLabel',public.app_zarcovi_live_format_b(z.tesouro_b),
      'syncedAt',to_char(z.synced_at,'DD/MM/YYYY HH24:MI')
    ) end,
    'emshby',case when em.account_code is null then null else jsonb_build_object(
      'accountCode',em.account_code,
      'ryosB',em.ryos_visible_b,
      'ryosLabel',public.app_zarcovi_live_format_b(em.ryos_visible_b),
      'tesouroLabel',public.app_zarcovi_live_format_b(em.tesouro_b),
      'syncedAt',to_char(em.synced_at,'DD/MM/YYYY HH24:MI')
    ) end
  );
end;
$$;

drop function if exists public.app_zarcovi_live_status(text);
create or replace function public.app_zarcovi_live_status(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare a public.app_members; src public.zarcovi_live_sources; total int; em public.zarcovi_live_accounts;
begin
  a:=public.v25_current(p_token);
  if not public.app_zarcovi_live_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if;

  select * into src from public.zarcovi_live_sources where source_key='banco01';
  select count(*) into total from public.zarcovi_live_accounts;
  select * into em from public.zarcovi_live_accounts where account_code='EMSHBY';

  return jsonb_build_object(
    'ok',true,
    'source',jsonb_build_object(
      'sourceUrl',src.source_url,
      'lastSyncAt',src.last_sync_at,
      'lastStatus',src.last_status,
      'lastCount',src.last_count
    ),
    'totalAccounts',total,
    'emshby',case when em.account_code is null then null else jsonb_build_object(
      'ryosLabel',public.app_zarcovi_live_format_b(em.ryos_visible_b),
      'tesouroLabel',public.app_zarcovi_live_format_b(em.tesouro_b),
      'syncedAt',em.synced_at
    ) end,
    'limits',jsonb_build_object('min','1500B / 1,5T','max','3T')
  );
end;
$$;

insert into public.app_routes(route_key, route_title, route_path, route_group, requires_role, icon, display_order, active, updated_at)
values
('zarcovi_live_sync_034','Zarcovi Sync','/owner/zarcovi-sync.html','admin','admin','history',38,true,now())
on conflict(route_key) do update set
  route_title=excluded.route_title,
  route_path=excluded.route_path,
  route_group=excluded.route_group,
  requires_role=excluded.requires_role,
  icon=excluded.icon,
  display_order=excluded.display_order,
  active=true,
  updated_at=now();

grant execute on function public.app_zarcovi_live_format_b(numeric) to anon, authenticated;
grant execute on function public.app_zarcovi_live_set_source(text,text) to anon, authenticated;
grant execute on function public.app_zarcovi_live_upsert_accounts(text,text,text,jsonb) to anon, authenticated;
grant execute on function public.app_zarcovi_live_apply_emshby(text) to anon, authenticated;
grant execute on function public.app_zarcovi_live_member_balance(text) to anon, authenticated;
grant execute on function public.app_zarcovi_live_status(text) to anon, authenticated;

select 'BLINDERS_0_3_4_ZARCOVI_LIVE_SYNC_OK' as status;


-- ============================================================
-- ZIP: blinders-cassino-0-3-5-apps-script-shop-fix-sql.zip
-- FILE: BLINDERS_0_3_5_APPS_SCRIPT_SHOP_FIX.sql
-- ============================================================

-- ============================================================
-- BLINDERS CASSINO — 0.3.5 APPS SCRIPT + SHOP FIX
-- Corrige app_mod030_admin_shop_items(p_token)
-- Adiciona sincronização estável via Google Apps Script
-- Rode depois da 0.3.4.
-- Resultado esperado: BLINDERS_0_3_5_APPS_SCRIPT_SHOP_FIX_OK
-- ============================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ------------------------------------------------------------
-- Compatibilidade mínima de tabelas
-- ------------------------------------------------------------
create table if not exists public.shop_items (
  id uuid primary key default extensions.gen_random_uuid(),
  item_key text unique,
  name text,
  category text,
  rarity text,
  price_units numeric(40,2) not null default 0,
  bonus jsonb not null default '{}',
  active boolean not null default true,
  created_at timestamptz default now()
);

alter table public.shop_items add column if not exists item_key text;
alter table public.shop_items add column if not exists name text;
alter table public.shop_items add column if not exists category text;
alter table public.shop_items add column if not exists rarity text;
alter table public.shop_items add column if not exists price_units numeric(40,2) not null default 0;
alter table public.shop_items add column if not exists bonus jsonb not null default '{}';
alter table public.shop_items add column if not exists active boolean not null default true;
alter table public.shop_items add column if not exists stock_limit int;
alter table public.shop_items add column if not exists sold_count int not null default 0;
alter table public.shop_items add column if not exists safe_equip_type text default 'none';
alter table public.shop_items add column if not exists event_item boolean not null default false;

create unique index if not exists uq_shop_items_item_key_035 on public.shop_items(item_key);

insert into public.shop_items(item_key,name,category,rarity,price_units,bonus,active)
values
('starter_ticket','Ticket Inicial','consumivel','comum',1500000000000,'{"type":"starter"}',true),
('gold_frame','Moldura Dourada','moldura','raro',3000000000000,'{"safe":true}',true),
('vip_title','Título VIP','titulo','epico',3000000000000,'{"safe":true}',true)
on conflict(item_key) do nothing;

-- ------------------------------------------------------------
-- CORREÇÃO DA LOJA
-- A função precisa existir exatamente como:
-- public.app_mod030_admin_shop_items(p_token)
-- ------------------------------------------------------------
drop function if exists public.app_mod030_admin_shop_items(text);

create or replace function public.app_mod030_admin_shop_items(p_token text)
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

  if coalesce(a.role,'user') not in ('admin','owner') then
    raise exception 'Acesso reservado para admin/dono.';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', si.id,
    'key', coalesce(si.item_key, si.id::text),
    'itemKey', coalesce(si.item_key, si.id::text),
    'name', coalesce(si.name, si.item_key, 'Item'),
    'category', coalesce(si.category, 'item'),
    'rarity', coalesce(si.rarity, 'comum'),
    'priceUnits', coalesce(si.price_units, 0),
    'priceLabel', public.v25_format(coalesce(si.price_units, 0)),
    'bonus', coalesce(si.bonus, '{}'::jsonb),
    'active', coalesce(si.active, true),
    'stockLimit', si.stock_limit,
    'soldCount', coalesce(si.sold_count, 0),
    'safeEquipType', coalesce(si.safe_equip_type, 'none'),
    'eventItem', coalesce(si.event_item, false)
  ) order by coalesce(si.category,'item'), coalesce(si.rarity,'comum'), coalesce(si.name,si.item_key)), '[]'::jsonb)
  into rows
  from public.shop_items si
  where coalesce(si.active,true)=true;

  return jsonb_build_object('ok', true, 'items', rows);
end;
$$;

grant execute on function public.app_mod030_admin_shop_items(text) to anon, authenticated;

-- ------------------------------------------------------------
-- Apps Script Sync com segredo
-- ------------------------------------------------------------
create table if not exists public.zarcovi_live_sources (
  source_key text primary key default 'banco01',
  source_name text not null default 'Zarcovi banco 01',
  source_url text,
  enabled boolean not null default true,
  last_sync_at timestamptz,
  last_status text,
  last_count int not null default 0,
  updated_by uuid references public.app_members(id) on delete set null,
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

create table if not exists public.zarcovi_apps_script_keys (
  id int primary key default 1,
  secret_hash text,
  enabled boolean not null default true,
  created_by uuid references public.app_members(id) on delete set null,
  updated_at timestamptz default now(),
  constraint zarcovi_apps_script_keys_singleton check(id=1)
);

insert into public.zarcovi_apps_script_keys(id) values(1) on conflict(id) do nothing;

create table if not exists public.zarcovi_apps_script_runs (
  id uuid primary key default extensions.gen_random_uuid(),
  source_key text not null default 'banco01',
  source_url text,
  imported_count int not null default 0,
  emshby_found boolean not null default false,
  status text not null default 'ok',
  message text,
  created_at timestamptz default now()
);

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

alter table public.iris_bank_accounts_mod020 add column if not exists status text not null default 'active';

insert into public.iris_bank_accounts_mod020(bank_key,display_name,iris_id)
values('EMSHBY','Banco EMSHBY','EMSHBY')
on conflict(bank_key) do nothing;

drop function if exists public.app_zarcovi_register_apps_script_secret(text,text);
create or replace function public.app_zarcovi_register_apps_script_secret(p_token text, p_secret text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  a public.app_members;
begin
  a := public.v25_current(p_token);

  if coalesce(a.role,'user') not in ('admin','owner') then
    raise exception 'Acesso reservado para admin/dono.';
  end if;

  if length(coalesce(p_secret,'')) < 12 then
    raise exception 'Use um segredo com pelo menos 12 caracteres.';
  end if;

  update public.zarcovi_apps_script_keys
  set secret_hash = extensions.crypt(p_secret, extensions.gen_salt('bf')),
      enabled = true,
      created_by = a.id,
      updated_at = now()
  where id=1;

  return jsonb_build_object('ok',true,'message','Segredo Apps Script cadastrado.');
end;
$$;

drop function if exists public.app_zarcovi_live_apps_script_push(text,text,text,jsonb);
create or replace function public.app_zarcovi_live_apps_script_push(
  p_secret text,
  p_source_key text,
  p_source_url text,
  p_accounts jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  k public.zarcovi_apps_script_keys;
  imported int := 0;
  em public.zarcovi_live_accounts;
  source_key text := coalesce(nullif(p_source_key,''),'banco01');
begin
  select * into k from public.zarcovi_apps_script_keys where id=1;

  if k.id is null or not coalesce(k.enabled,false) or k.secret_hash is null then
    raise exception 'Apps Script Sync não configurado.';
  end if;

  if k.secret_hash <> extensions.crypt(coalesce(p_secret,''), k.secret_hash) then
    raise exception 'Segredo inválido.';
  end if;

  insert into public.zarcovi_live_accounts(
    account_code, source_key, source_row, kind, vila, level_num,
    ryos_visible_b, ryos_units, salario_b, salario_units, cargos,
    vontade_fogo, vontade_pedra, personagem, tesouro_b, tesouro_units,
    raw_data, synced_at, updated_at
  )
  select
    upper(trim(x.conta)),
    source_key,
    x."sourceRow",
    x.kind,
    x.vila,
    coalesce(x.level,0),
    coalesce(x."ryosB",0),
    coalesce(x."ryosB",0) * 1000000000,
    coalesce(x."salarioB",0),
    coalesce(x."salarioB",0) * 1000000000,
    x.cargos,
    coalesce(x.fogo,0),
    coalesce(x.pedra,0),
    x.personagem,
    coalesce(x."tesouroB",0),
    coalesce(x."tesouroB",0) * 1000000000,
    to_jsonb(x),
    now(),
    now()
  from jsonb_to_recordset(coalesce(p_accounts,'[]'::jsonb)) as x(
    "sourceRow" int,
    kind text,
    vila text,
    conta text,
    level numeric,
    "ryosB" numeric,
    "salarioB" numeric,
    cargos text,
    fogo numeric,
    pedra numeric,
    personagem text,
    "tesouroB" numeric,
    raw jsonb
  )
  where coalesce(trim(x.conta),'') <> ''
  on conflict(account_code) do update set
    source_key=excluded.source_key,
    source_row=excluded.source_row,
    kind=excluded.kind,
    vila=excluded.vila,
    level_num=excluded.level_num,
    ryos_visible_b=excluded.ryos_visible_b,
    ryos_units=excluded.ryos_units,
    salario_b=excluded.salario_b,
    salario_units=excluded.salario_units,
    cargos=excluded.cargos,
    vontade_fogo=excluded.vontade_fogo,
    vontade_pedra=excluded.vontade_pedra,
    personagem=excluded.personagem,
    tesouro_b=excluded.tesouro_b,
    tesouro_units=excluded.tesouro_units,
    raw_data=excluded.raw_data,
    synced_at=now(),
    updated_at=now();

  get diagnostics imported = row_count;

  insert into public.zarcovi_live_sources(source_key,source_name,source_url,last_sync_at,last_status,last_count,updated_at)
  values(source_key,'Zarcovi banco 01',p_source_url,now(),'apps_script_sync',imported,now())
  on conflict(source_key) do update set
    source_url=excluded.source_url,
    last_sync_at=now(),
    last_status='apps_script_sync',
    last_count=imported,
    updated_at=now();

  select * into em from public.zarcovi_live_accounts where account_code='EMSHBY';

  if em.account_code is not null then
    update public.iris_bank_accounts_mod020
    set balance_units = em.ryos_units,
        status = case when em.ryos_units <= 0 then 'empty' else 'active' end,
        updated_at = now()
    where bank_key='EMSHBY';
  end if;

  insert into public.zarcovi_apps_script_runs(source_key,source_url,imported_count,emshby_found,status,message)
  values(source_key,p_source_url,imported,em.account_code is not null,'ok','Sincronização Apps Script concluída.');

  return jsonb_build_object(
    'ok',true,
    'imported',imported,
    'emshbyFound',em.account_code is not null,
    'emshbyBalanceUnits',case when em.account_code is null then null else em.ryos_units end
  );
end;
$$;

grant execute on function public.app_zarcovi_register_apps_script_secret(text,text) to anon, authenticated;
grant execute on function public.app_zarcovi_live_apps_script_push(text,text,text,jsonb) to anon, authenticated;

-- Rota
insert into public.app_routes(route_key, route_title, route_path, route_group, requires_role, icon, display_order, active, updated_at)
values
('apps_script_sync_035','Apps Script Sync','/owner/apps-script-sync.html','admin','admin','settings',39,true,now())
on conflict(route_key) do update set
  route_title=excluded.route_title,
  route_path=excluded.route_path,
  route_group=excluded.route_group,
  requires_role=excluded.requires_role,
  icon=excluded.icon,
  display_order=excluded.display_order,
  active=true,
  updated_at=now();

-- Ajuda o PostgREST a perceber funções novas mais rápido
notify pgrst, 'reload schema';

select 'BLINDERS_0_3_5_APPS_SCRIPT_SHOP_FIX_OK' as status;


-- ============================================================
-- ZIP: blinders-cassino-0-3-6-guest-sheet-sync-sql.zip
-- FILE: BLINDERS_0_3_6_GUEST_SHEET_SYNC.sql
-- ============================================================

-- ============================================================
-- BLINDERS CASSINO — 0.3.6 GUEST SHEET SYNC
-- Usa planilha somente como convidado/leitura.
-- Não precisa de Apps Script, não altera a planilha.
-- Rode depois da 0.3.5.
-- Resultado esperado: BLINDERS_0_3_6_GUEST_SHEET_SYNC_OK
-- ============================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.zarcovi_live_sources (
  source_key text primary key default 'banco01',
  source_name text not null default 'Zarcovi banco 01',
  source_url text,
  enabled boolean not null default true,
  last_sync_at timestamptz,
  last_status text,
  last_count int not null default 0,
  updated_by uuid references public.app_members(id) on delete set null,
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

alter table public.iris_bank_accounts_mod020 add column if not exists status text not null default 'active';

insert into public.iris_bank_accounts_mod020(bank_key,display_name,iris_id)
values('EMSHBY','Banco EMSHBY','EMSHBY')
on conflict(bank_key) do nothing;

drop function if exists public.app_guest_sheet_is_admin(public.app_members);
create or replace function public.app_guest_sheet_is_admin(m public.app_members)
returns boolean language sql stable as $$
  select coalesce(m.role,'user') in ('admin','owner')
$$;

drop function if exists public.app_guest_sheet_format_b(numeric);
create or replace function public.app_guest_sheet_format_b(p_b numeric)
returns text
language plpgsql
immutable
as $$
begin
  if abs(coalesce(p_b,0)) >= 1000 then
    return trim(to_char(coalesce(p_b,0)/1000,'FM999999999999990D00')) || 'T';
  end if;
  return trim(to_char(coalesce(p_b,0),'FM999999999999990D00')) || 'B';
end;
$$;

drop function if exists public.app_guest_sheet_sync_push(text,text,jsonb);
create or replace function public.app_guest_sheet_sync_push(
  p_token text,
  p_source_url text,
  p_accounts jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  a public.app_members;
  imported int := 0;
  em public.zarcovi_live_accounts;
begin
  a := public.v25_current(p_token);

  if not public.app_guest_sheet_is_admin(a) then
    raise exception 'Acesso reservado para admin/dono.';
  end if;

  insert into public.zarcovi_live_accounts(
    account_code, source_key, source_row, kind, vila, level_num,
    ryos_visible_b, ryos_units, salario_b, salario_units, cargos,
    vontade_fogo, vontade_pedra, personagem, tesouro_b, tesouro_units,
    raw_data, synced_at, updated_at
  )
  select
    upper(trim(x.conta)),
    'banco01',
    x."sourceRow",
    x.kind,
    x.vila,
    coalesce(x.level,0),
    coalesce(x."ryosB",0),
    coalesce(x."ryosB",0) * 1000000000,
    coalesce(x."salarioB",0),
    coalesce(x."salarioB",0) * 1000000000,
    x.cargos,
    coalesce(x.fogo,0),
    coalesce(x.pedra,0),
    x.personagem,
    coalesce(x."tesouroB",0),
    coalesce(x."tesouroB",0) * 1000000000,
    to_jsonb(x),
    now(),
    now()
  from jsonb_to_recordset(coalesce(p_accounts,'[]'::jsonb)) as x(
    "sourceRow" int,
    kind text,
    vila text,
    conta text,
    level numeric,
    "ryosB" numeric,
    "salarioB" numeric,
    cargos text,
    fogo numeric,
    pedra numeric,
    personagem text,
    "tesouroB" numeric,
    raw jsonb
  )
  where coalesce(trim(x.conta),'') <> ''
  on conflict(account_code) do update set
    source_key=excluded.source_key,
    source_row=excluded.source_row,
    kind=excluded.kind,
    vila=excluded.vila,
    level_num=excluded.level_num,
    ryos_visible_b=excluded.ryos_visible_b,
    ryos_units=excluded.ryos_units,
    salario_b=excluded.salario_b,
    salario_units=excluded.salario_units,
    cargos=excluded.cargos,
    vontade_fogo=excluded.vontade_fogo,
    vontade_pedra=excluded.vontade_pedra,
    personagem=excluded.personagem,
    tesouro_b=excluded.tesouro_b,
    tesouro_units=excluded.tesouro_units,
    raw_data=excluded.raw_data,
    synced_at=now(),
    updated_at=now();

  get diagnostics imported = row_count;

  insert into public.zarcovi_live_sources(source_key,source_name,source_url,last_sync_at,last_status,last_count,updated_by,updated_at)
  values('banco01','Zarcovi banco 01',p_source_url,now(),'guest_read_only_sync',imported,a.id,now())
  on conflict(source_key) do update set
    source_url=excluded.source_url,
    last_sync_at=now(),
    last_status='guest_read_only_sync',
    last_count=imported,
    updated_by=a.id,
    updated_at=now();

  select * into em from public.zarcovi_live_accounts where account_code='EMSHBY';

  if em.account_code is not null then
    update public.iris_bank_accounts_mod020
    set balance_units = em.ryos_units,
        status = case when em.ryos_units <= 0 then 'empty' else 'active' end,
        updated_at = now()
    where bank_key='EMSHBY';
  end if;

  return jsonb_build_object(
    'ok',true,
    'imported',imported,
    'mode','guest_read_only',
    'emshby',case when em.account_code is null then null else jsonb_build_object(
      'accountCode',em.account_code,
      'ryosB',em.ryos_visible_b,
      'ryosLabel',public.app_guest_sheet_format_b(em.ryos_visible_b),
      'syncedAt',em.synced_at
    ) end
  );
end;
$$;

drop function if exists public.app_guest_sheet_sync_status(text);
create or replace function public.app_guest_sheet_sync_status(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  a public.app_members;
  src public.zarcovi_live_sources;
  total int;
  em public.zarcovi_live_accounts;
begin
  a := public.v25_current(p_token);

  if not public.app_guest_sheet_is_admin(a) then
    raise exception 'Acesso reservado para admin/dono.';
  end if;

  select * into src from public.zarcovi_live_sources where source_key='banco01';
  select count(*) into total from public.zarcovi_live_accounts;
  select * into em from public.zarcovi_live_accounts where account_code='EMSHBY';

  return jsonb_build_object(
    'ok',true,
    'mode','guest_read_only',
    'source',jsonb_build_object(
      'sourceUrl',src.source_url,
      'lastSyncAt',src.last_sync_at,
      'lastStatus',src.last_status,
      'lastCount',src.last_count
    ),
    'totalAccounts',total,
    'emshby',case when em.account_code is null then null else jsonb_build_object(
      'ryosLabel',public.app_guest_sheet_format_b(em.ryos_visible_b),
      'syncedAt',em.synced_at
    ) end
  );
end;
$$;

insert into public.app_routes(route_key, route_title, route_path, route_group, requires_role, icon, display_order, active, updated_at)
values
('guest_sheet_sync_036','Planilha Convidado','/owner/guest-sheet-sync.html','admin','admin','history',40,true,now())
on conflict(route_key) do update set
  route_title=excluded.route_title,
  route_path=excluded.route_path,
  route_group=excluded.route_group,
  requires_role=excluded.requires_role,
  icon=excluded.icon,
  display_order=excluded.display_order,
  active=true,
  updated_at=now();

grant execute on function public.app_guest_sheet_format_b(numeric) to anon, authenticated;
grant execute on function public.app_guest_sheet_sync_push(text,text,jsonb) to anon, authenticated;
grant execute on function public.app_guest_sheet_sync_status(text) to anon, authenticated;

notify pgrst, 'reload schema';

select 'BLINDERS_0_3_6_GUEST_SHEET_SYNC_OK' as status;


-- ============================================================
-- ZIP: blinders-cassino-0-3-7-consolidado-sql.zip
-- FILE: BLINDERS_0_3_7_CONSOLIDADO.sql
-- ============================================================

-- ============================================================
-- BLINDERS CASSINO — 0.3.7 CONSOLIDADO
-- Sync só de contas criadas no app + EMSHBY, registro validado pela planilha,
-- checagem de transferências EMSHBY e menu consolidado.
-- Rode depois da 0.3.6.
-- Resultado esperado: BLINDERS_0_3_7_CONSOLIDADO_OK
-- ============================================================
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create table if not exists public.zarcovi_live_sources(source_key text primary key default 'banco01',source_name text not null default 'Zarcovi banco 01',source_url text,enabled boolean not null default true,last_sync_at timestamptz,last_status text,last_count int not null default 0,updated_by uuid references public.app_members(id) on delete set null,updated_at timestamptz default now());
create table if not exists public.zarcovi_live_accounts(account_code text primary key,source_key text not null default 'banco01',source_row int,kind text,vila text,level_num numeric(12,2) default 0,ryos_visible_b numeric(40,2) default 0,ryos_units numeric(40,2) default 0,salario_b numeric(40,2) default 0,salario_units numeric(40,2) default 0,cargos text,vontade_fogo numeric(12,2) default 0,vontade_pedra numeric(12,2) default 0,personagem text,tesouro_b numeric(40,2) default 0,tesouro_units numeric(40,2) default 0,raw_data jsonb not null default '{}',synced_at timestamptz default now(),updated_at timestamptz default now());
create table if not exists public.zarcovi_sync_rejections_037(id uuid primary key default extensions.gen_random_uuid(),account_code text,reason text,raw_data jsonb not null default '{}',created_at timestamptz default now());
create table if not exists public.iris_bank_accounts_mod020(bank_key text primary key,display_name text not null,iris_id text not null unique,balance_units numeric(40,2) not null default 0,deposits_total_units numeric(40,2) not null default 0,table_fee_units numeric(40,2) not null default 0,solo_profit_units numeric(40,2) not null default 0,updated_at timestamptz default now());
alter table public.iris_bank_accounts_mod020 add column if not exists status text not null default 'active';
alter table public.iris_bank_accounts_mod020 add column if not exists reserve_percent numeric(8,2) not null default 10;
alter table public.iris_bank_accounts_mod020 add column if not exists max_single_prize_percent numeric(8,2) not null default 10;
insert into public.iris_bank_accounts_mod020(bank_key,display_name,iris_id) values('EMSHBY','Banco EMSHBY','EMSHBY') on conflict(bank_key) do nothing;
alter table public.app_members add column if not exists zarcovi_account text;
alter table public.app_members add column if not exists friend_code text;
alter table public.app_members add column if not exists balance_virtual_units numeric(40,2) not null default 0;
create table if not exists public.deposit_requests(id uuid primary key default extensions.gen_random_uuid(),member_id uuid references public.app_members(id) on delete set null,amount_units numeric(40,2) not null default 0,account_used text,status text not null default 'pending',tx_id uuid,confirmed_by uuid references public.app_members(id) on delete set null,confirmed_at timestamptz,created_at timestamptz default now());
alter table public.deposit_requests add column if not exists account_used text;
alter table public.deposit_requests add column if not exists amount_units numeric(40,2) not null default 0;
alter table public.deposit_requests add column if not exists status text not null default 'pending';
alter table public.deposit_requests add column if not exists confirmed_by uuid references public.app_members(id) on delete set null;
alter table public.deposit_requests add column if not exists confirmed_at timestamptz;
create table if not exists public.public_transfer_log_037(id uuid primary key default extensions.gen_random_uuid(),raw_line text not null,from_account text,to_account text,amount_b numeric(40,2) default 0,amount_units numeric(40,2) default 0,transfer_date text,matched_deposit_id uuid,status text not null default 'parsed',created_at timestamptz default now());
drop function if exists public.app_con037_is_admin(public.app_members);
create or replace function public.app_con037_is_admin(m public.app_members) returns boolean language sql stable as $$ select coalesce(m.role,'user') in ('admin','owner') $$;
drop function if exists public.app_con037_format_b(numeric);
create or replace function public.app_con037_format_b(p_b numeric) returns text language plpgsql immutable as $$ begin if abs(coalesce(p_b,0)) >= 1000 then return trim(to_char(coalesce(p_b,0)/1000,'FM999999999999990D00')) || 'T'; end if; return trim(to_char(coalesce(p_b,0),'FM999999999999990D00')) || 'B'; end; $$;
drop function if exists public.app_con037_parse_amount_from_text(text);
create or replace function public.app_con037_parse_amount_from_text(p_line text) returns numeric language plpgsql immutable as $$ declare m text[]; val numeric; unit text; begin m:=regexp_match(upper(coalesce(p_line,'')),'([0-9]+([\.,][0-9]+)?)\s*(T|B)'); if m is null then return 0; end if; val:=replace(m[1],',','.')::numeric; unit:=m[3]; if unit='T' then return val*1000000000000; end if; return val*1000000000; end; $$;
drop function if exists public.app_con037_app_account_codes(text);
create or replace function public.app_con037_app_account_codes(p_token text) returns jsonb language plpgsql security definer set search_path=public,extensions as $$ declare a public.app_members; codes jsonb; begin a:=public.v25_current(p_token); if not public.app_con037_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if; select coalesce(jsonb_agg(distinct upper(trim(coalesce(zarcovi_account,nick,'')))),'[]'::jsonb) into codes from public.app_members where coalesce(trim(coalesce(zarcovi_account,nick,'')),'')<>''; return jsonb_build_object('ok',true,'codes',codes); end; $$;
drop function if exists public.app_con037_sync_app_accounts_only(text,text,jsonb);
create or replace function public.app_con037_sync_app_accounts_only(p_token text,p_source_url text,p_accounts jsonb) returns jsonb language plpgsql security definer set search_path=public,extensions as $$ declare a public.app_members; imported int:=0; ignored int:=0; em public.zarcovi_live_accounts; matched jsonb; begin a:=public.v25_current(p_token); if not public.app_con037_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if; with incoming as (select upper(trim(x.conta)) as account_code,x.* from jsonb_to_recordset(coalesce(p_accounts,'[]'::jsonb)) as x("sourceRow" int,kind text,vila text,conta text,level numeric,"ryosB" numeric,"salarioB" numeric,cargos text,fogo numeric,pedra numeric,personagem text,"tesouroB" numeric,raw jsonb) where coalesce(trim(x.conta),'')<>''), app_codes as (select distinct upper(trim(coalesce(zarcovi_account,nick,''))) as account_code from public.app_members where coalesce(trim(coalesce(zarcovi_account,nick,'')),'')<>''), accepted as (select i.* from incoming i where i.account_code='EMSHBY' or exists(select 1 from app_codes ac where ac.account_code=i.account_code)), rejected as (insert into public.zarcovi_sync_rejections_037(account_code,reason,raw_data) select i.account_code,'not_created_in_app',to_jsonb(i) from incoming i where i.account_code<>'EMSHBY' and not exists(select 1 from app_codes ac where ac.account_code=i.account_code) returning 1), upserted as (insert into public.zarcovi_live_accounts(account_code,source_key,source_row,kind,vila,level_num,ryos_visible_b,ryos_units,salario_b,salario_units,cargos,vontade_fogo,vontade_pedra,personagem,tesouro_b,tesouro_units,raw_data,synced_at,updated_at) select a.account_code,'banco01',a."sourceRow",a.kind,a.vila,coalesce(a.level,0),coalesce(a."ryosB",0),coalesce(a."ryosB",0)*1000000000,coalesce(a."salarioB",0),coalesce(a."salarioB",0)*1000000000,a.cargos,coalesce(a.fogo,0),coalesce(a.pedra,0),a.personagem,coalesce(a."tesouroB",0),coalesce(a."tesouroB",0)*1000000000,to_jsonb(a),now(),now() from accepted a on conflict(account_code) do update set source_key=excluded.source_key,source_row=excluded.source_row,kind=excluded.kind,vila=excluded.vila,level_num=excluded.level_num,ryos_visible_b=excluded.ryos_visible_b,ryos_units=excluded.ryos_units,salario_b=excluded.salario_b,salario_units=excluded.salario_units,cargos=excluded.cargos,vontade_fogo=excluded.vontade_fogo,vontade_pedra=excluded.vontade_pedra,personagem=excluded.personagem,tesouro_b=excluded.tesouro_b,tesouro_units=excluded.tesouro_units,raw_data=excluded.raw_data,synced_at=now(),updated_at=now() returning account_code,ryos_visible_b) select (select count(*) from upserted),(select count(*) from rejected),coalesce(jsonb_agg(jsonb_build_object('accountCode',account_code,'ryosLabel',public.app_con037_format_b(ryos_visible_b))),'[]'::jsonb) into imported,ignored,matched from upserted; insert into public.zarcovi_live_sources(source_key,source_name,source_url,last_sync_at,last_status,last_count,updated_by,updated_at) values('banco01','Zarcovi banco 01',p_source_url,now(),'app_accounts_only',coalesce(imported,0),a.id,now()) on conflict(source_key) do update set source_url=excluded.source_url,last_sync_at=now(),last_status='app_accounts_only',last_count=excluded.last_count,updated_by=a.id,updated_at=now(); select * into em from public.zarcovi_live_accounts where account_code='EMSHBY'; if em.account_code is not null then update public.iris_bank_accounts_mod020 set balance_units=em.ryos_units,status=case when em.ryos_units<=0 then 'empty' else 'active' end,updated_at=now() where bank_key='EMSHBY'; end if; return jsonb_build_object('ok',true,'mode','app_accounts_only','imported',coalesce(imported,0),'ignored',coalesce(ignored,0),'matched',coalesce(matched,'[]'::jsonb),'emshby',case when em.account_code is null then null else jsonb_build_object('accountCode',em.account_code,'ryosB',em.ryos_visible_b,'ryosLabel',public.app_con037_format_b(em.ryos_visible_b),'syncedAt',em.synced_at) end); end; $$;
drop function if exists public.app_con037_sync_status(text);
create or replace function public.app_con037_sync_status(p_token text) returns jsonb language plpgsql security definer set search_path=public,extensions as $$ declare a public.app_members; src public.zarcovi_live_sources; total int; app_total int; em public.zarcovi_live_accounts; begin a:=public.v25_current(p_token); if not public.app_con037_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if; select * into src from public.zarcovi_live_sources where source_key='banco01'; select count(*) into total from public.zarcovi_live_accounts; select count(*) into app_total from public.app_members; select * into em from public.zarcovi_live_accounts where account_code='EMSHBY'; return jsonb_build_object('ok',true,'mode','app_accounts_only','source',jsonb_build_object('sourceUrl',src.source_url,'lastSyncAt',src.last_sync_at,'lastStatus',src.last_status,'lastCount',src.last_count),'syncedAccounts',total,'appAccounts',app_total,'emshby',case when em.account_code is null then null else jsonb_build_object('ryosLabel',public.app_con037_format_b(em.ryos_visible_b),'syncedAt',em.synced_at) end); end; $$;
-- Registro validado por planilha já sincronizada. Cria overload comum usado pelo app.
drop function if exists public.app_register(text,text,text,text,text);
create or replace function public.app_register(p_nick text,p_zarcovi_account text,p_password text,p_phone text default null,p_user_agent text default null) returns jsonb language plpgsql security definer set search_path=public,extensions as $$ declare clean_nick text:=trim(coalesce(p_nick,'')); clean_acc text:=upper(trim(coalesce(p_zarcovi_account,''))); z public.zarcovi_live_accounts; new_id uuid; begin if length(clean_nick)<2 then raise exception 'Nick muito curto.'; end if; if length(clean_acc)<2 then raise exception 'Conta Zarcovi inválida.'; end if; if length(coalesce(p_password,''))<4 then raise exception 'Senha muito curta.'; end if; select * into z from public.zarcovi_live_accounts where account_code=clean_acc; if z.account_code is null then raise exception 'Conta Zarcovi não encontrada na planilha sincronizada. Peça para um admin sincronizar antes de criar a conta.'; end if; if exists(select 1 from public.app_members where lower(nick)=lower(clean_nick) or upper(zarcovi_account)=clean_acc) then raise exception 'Nick ou conta Zarcovi já cadastrados.'; end if; insert into public.app_members(nick,zarcovi_account,password_hash,role,status,balance_virtual_units,iris_member_id,friend_code,created_at,updated_at) values(clean_nick,clean_acc,extensions.crypt(p_password,extensions.gen_salt('bf')),'user','pending',coalesce(z.ryos_units,0),'IRIS-'||upper(substr(encode(extensions.gen_random_bytes(5),'hex'),1,10)),'FR-'||upper(substr(encode(extensions.gen_random_bytes(5),'hex'),1,10)),now(),now()) returning id into new_id; return jsonb_build_object('ok',true,'message','Conta criada e aguardando confirmação do admin. Saldo Zarcovi vinculado.','memberId',new_id); end; $$;
grant execute on function public.app_register(text,text,text,text,text) to anon, authenticated;
drop function if exists public.app_con037_pending_deposits(text);
create or replace function public.app_con037_pending_deposits(p_token text) returns jsonb language plpgsql security definer set search_path=public,extensions as $$ declare a public.app_members; rows jsonb; begin a:=public.v25_current(p_token); if not public.app_con037_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if; select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'member',m.nick,'account',coalesce(d.account_used,m.zarcovi_account),'amountLabel',public.v25_format(d.amount_units),'status',d.status,'createdAt',to_char(d.created_at,'DD/MM HH24:MI')) order by d.created_at desc),'[]'::jsonb) into rows from public.deposit_requests d join public.app_members m on m.id=d.member_id where d.status='pending'; return jsonb_build_object('ok',true,'pending',rows); end; $$;
drop function if exists public.app_con037_check_public_transfer_log(text,jsonb);
create or replace function public.app_con037_check_public_transfer_log(p_token text,p_lines jsonb) returns jsonb language plpgsql security definer set search_path=public,extensions as $$ declare a public.app_members; rec record; line text; amount_units numeric; from_acc text; dep public.deposit_requests; log_id uuid; confirmed int:=0; parsed int:=0; results jsonb:='[]'::jsonb; begin a:=public.v25_current(p_token); if not public.app_con037_is_admin(a) then raise exception 'Acesso reservado para admin/dono.'; end if; for rec in select * from jsonb_to_recordset(coalesce(p_lines,'[]'::jsonb)) as x(line text,row int) loop line:=upper(coalesce(rec.line,'')); if trim(line)='' then continue; end if; amount_units:=public.app_con037_parse_amount_from_text(line); from_acc:=null; select upper(zarcovi_account) into from_acc from public.app_members where zarcovi_account is not null and line like '%'||upper(zarcovi_account)||'%' and upper(zarcovi_account)<>'EMSHBY' limit 1; if line like '%EMSHBY%' and amount_units>0 then parsed:=parsed+1; insert into public.public_transfer_log_037(raw_line,from_account,to_account,amount_units,amount_b,status) values(rec.line,from_acc,'EMSHBY',amount_units,amount_units/1000000000,'parsed') returning id into log_id; select d.* into dep from public.deposit_requests d join public.app_members m on m.id=d.member_id where d.status='pending' and d.amount_units=amount_units and (from_acc is null or upper(coalesce(d.account_used,m.zarcovi_account,''))=from_acc or line like '%'||upper(coalesce(d.account_used,m.zarcovi_account,''))||'%') order by d.created_at asc limit 1 for update; if dep.id is not null then update public.deposit_requests set status='confirmed',confirmed_by=a.id,confirmed_at=now() where id=dep.id; update public.app_members set balance_virtual_units=balance_virtual_units+dep.amount_units,updated_at=now() where id=dep.member_id; if dep.tx_id is not null and to_regclass('public.iris_transactions') is not null then update public.iris_transactions set status='completed',confirmed_at=now() where id=dep.tx_id; end if; update public.iris_bank_accounts_mod020 set balance_units=balance_units+dep.amount_units,deposits_total_units=deposits_total_units+dep.amount_units,status='active',updated_at=now() where bank_key='EMSHBY'; update public.public_transfer_log_037 set matched_deposit_id=dep.id,status='matched' where id=log_id; confirmed:=confirmed+1; results:=results||jsonb_build_array(jsonb_build_object('line',rec.line,'matched',true,'depositId',dep.id,'amountLabel',public.v25_format(dep.amount_units))); else results:=results||jsonb_build_array(jsonb_build_object('line',rec.line,'matched',false,'reason','Nenhum depósito pendente com mesmo valor/conta.')); end if; end if; end loop; return jsonb_build_object('ok',true,'parsedTransfersToEMSHBY',parsed,'confirmedDeposits',confirmed,'results',results); end; $$;
grant execute on function public.app_con037_app_account_codes(text) to anon, authenticated;
grant execute on function public.app_con037_sync_app_accounts_only(text,text,jsonb) to anon, authenticated;
grant execute on function public.app_con037_sync_status(text) to anon, authenticated;
grant execute on function public.app_con037_pending_deposits(text) to anon, authenticated;
grant execute on function public.app_con037_check_public_transfer_log(text,jsonb) to anon, authenticated;
insert into public.app_routes(route_key,route_title,route_path,route_group,requires_role,icon,display_order,active,updated_at) values ('menu_consolidado_037','Menu Geral','/menu.html','member','user','status',1,true,now()),('sync_app_only_037','Sync Seletivo','/owner/consolidated-sync.html','admin','admin','history',41,true,now()),('transfer_log_037','Checar Transferências','/owner/transfer-log.html','admin','admin','iris',42,true,now()) on conflict(route_key) do update set route_title=excluded.route_title,route_path=excluded.route_path,route_group=excluded.route_group,requires_role=excluded.requires_role,icon=excluded.icon,display_order=excluded.display_order,active=true,updated_at=now();
notify pgrst, 'reload schema';
select 'BLINDERS_0_3_7_CONSOLIDADO_OK' as status;


-- ============================================================
-- ZIP: blinders-cassino-0-3-8-iris-control-submenus-sql.zip
-- FILE: BLINDERS_0_3_8_IRIS_CONTROL_SUBMENUS.sql
-- ============================================================

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
