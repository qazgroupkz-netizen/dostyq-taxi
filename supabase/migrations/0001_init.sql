-- ALAKOL TAXI: схема базы для Supabase (замена Firestore).
-- Повторяет коллекции Firestore: users → profiles, drivers, driverDocs → driver_docs + Storage,
-- orders, trips, settings/{region} → settings, settings/streets_{region} → streets, places, regions.
-- Изменения, где важна проверка (принять заказ, ставка, бронь места), — только через функции (RPC).

create extension if not exists pgcrypto;

-- ───────────── Таблицы ─────────────

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null default '',
  phone text not null default '',
  role text not null default 'client' check (role in ('client','driver','manager','admin')),
  created_at timestamptz not null default now()
);

create table public.regions (
  id text primary key default gen_random_uuid()::text,
  name text not null,
  lat double precision not null,
  lng double precision not null,
  radius_km double precision not null default 8,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

-- Тарифы района: data — те же поля, что в settings/{region} (localPrice, seatPrice, offerSeconds…),
-- routes — цены межгорода по направлениям {to: {seat, whole, parcel}}.
create table public.settings (
  region_id text primary key,
  data jsonb not null default '{}',
  routes jsonb not null default '{}',
  updated_at timestamptz not null default now()
);

-- Улицы района одним списком, как settings/streets_{region}.list.
create table public.streets (
  region_id text primary key,
  list jsonb not null default '[]',
  updated_at timestamptz not null default now()
);

create table public.places (
  id text primary key default gen_random_uuid()::text,
  region text not null default 'dostyk',
  name text not null,
  sub text not null default '',
  category text not null default 'other',
  lat double precision not null,
  lng double precision not null,
  synonyms text[] not null default '{}',
  chip boolean not null default false,
  "group" text,
  approx boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.drivers (
  id uuid primary key references auth.users on delete cascade,
  name text not null default '',
  phone text not null default '',
  car_model text not null default '',
  car_color text not null default '',
  plate text not null default '',
  region text not null default 'dostyk',
  vehicle text not null default 'car' check (vehicle in ('car','cargo')),
  approval text not null default 'pending' check (approval in ('none','pending','approved','rejected','blocked')),
  reject_reason text,
  subscription_until timestamptz,
  submitted_at timestamptz,
  consent_at timestamptz,
  approved_at timestamptz,
  ip_until timestamptz,
  elicense_until timestamptz,
  status text not null default 'offline' check (status in ('online','offline')),
  lat double precision,
  lng double precision,
  location_at timestamptz
);

-- Фото документов лежат в Storage (bucket driver-docs, путь <uid>/<kind>.jpg), здесь — список.
create table public.driver_docs (
  driver_id uuid not null references public.drivers on delete cascade,
  kind text not null check (kind in ('license_front','license_back','techpass_front','techpass_back','car','ip','elicense')),
  path text not null,
  updated_at timestamptz not null default now(),
  primary key (driver_id, kind)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references auth.users on delete set null,
  manager_id uuid references auth.users on delete set null,   -- заказ по звонку (в Firestore clientId = "manager:<uid>")
  client_name text not null default '',
  client_phone text not null default '',
  from_label text not null default '',
  from_lat double precision,
  from_lng double precision,
  to_label text not null default '',
  to_lat double precision,
  to_lng double precision,
  region text not null,
  service text not null default 'local' check (service in ('local','border','whole','delivery','cargo')),
  price integer not null default 0,
  client_price integer,
  payment text not null default 'cash' check (payment in ('cash','kaspi')),
  status text not null default 'searching' check (status in ('searching','accepted','arrived','riding','done','cancelled')),
  created_by text not null default 'app' check (created_by in ('app','manager')),
  comment text,
  bids jsonb not null default '{}',          -- {driverUid: {driverName, car, plate, price, at}}
  driver_id uuid references public.drivers on delete set null,
  driver_name text,
  driver_car text,
  driver_plate text,
  client_coming_out boolean not null default false,
  declined_by uuid[] not null default '{}',
  rating smallint check (rating between 1 and 5),
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers on delete cascade,
  driver_name text not null default '',
  driver_phone text not null default '',
  car text not null default '',
  plate text not null default '',
  from_region text not null,
  to_region text not null,
  date date not null,
  time text not null,
  seat_price integer not null default 0,
  whole_price integer not null default 0,
  parcel_price integer not null default 0,
  status text not null default 'open' check (status in ('open','cancelled')),
  seats jsonb not null default '{}',         -- {"1": {clientId, name, phone}, …}
  whole jsonb,                               -- {clientId, name, phone}
  parcels jsonb not null default '{}',       -- {id: {clientId, senderName, senderPhone, what, toName, toPhone, price}}
  created_at timestamptz not null default now()
);

create index orders_region_status on public.orders (region, status);
create index orders_driver on public.orders (driver_id);
create index orders_client on public.orders (client_id);
create index orders_created on public.orders (created_at);
create index drivers_region_status on public.drivers (region, status);
create index trips_route_date on public.trips (from_region, to_region, date);
create index trips_driver on public.trips (driver_id);
create index places_region on public.places (region);

-- ───────────── Роли ─────────────

create function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select coalesce((select role from profiles where id = auth.uid()), 'client')
$$;

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select my_role() = 'admin'
$$;

create function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select my_role() in ('admin','manager')
$$;

-- Водитель одобрен и подписка не закончилась.
create function public.is_active_driver() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from drivers d where d.id = auth.uid()
    and d.approval = 'approved' and d.subscription_until > now())
$$;

create function public.my_driver_region() returns text
language sql stable security definer set search_path = public as $$
  select region from drivers where id = auth.uid()
$$;

-- ───────────── Служебные триггеры ─────────────

create function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

create trigger orders_touch before update on public.orders for each row execute function public.touch_updated_at();
create trigger settings_touch before update on public.settings for each row execute function public.touch_updated_at();
create trigger streets_touch before update on public.streets for each row execute function public.touch_updated_at();
create trigger places_touch before update on public.places for each row execute function public.touch_updated_at();
create trigger regions_touch before update on public.regions for each row execute function public.touch_updated_at();

-- Запрос пришёл от приложения (anon/authenticated), а не от сервера или консоли базы.
create function public.from_app() returns boolean
language sql stable as $$
  select coalesce(auth.role(), '') in ('anon','authenticated')
$$;

-- Водитель не может сам себя одобрить или продлить подписку: эти поля меняет только админ.
create function public.drivers_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not from_app() or is_admin() then return new; end if;
  if tg_op = 'INSERT' then
    new.approval := 'pending';
    new.subscription_until := null;
    new.approved_at := null;
    new.reject_reason := null;
    return new;
  end if;
  -- Повторная отправка анкеты после отказа — снова «на проверке».
  if new.approval = 'pending' and old.approval in ('none','pending','rejected') then
    new.reject_reason := null;
  else
    new.approval := old.approval;
    new.reject_reason := old.reject_reason;
  end if;
  new.subscription_until := old.subscription_until;
  new.approved_at := old.approved_at;
  -- Заблокированный или неодобренный водитель не выходит на линию.
  if new.status = 'online' and not (new.approval = 'approved' and coalesce(new.subscription_until > now(), false)) then
    new.status := 'offline';
  end if;
  return new;
end $$;

create trigger drivers_guard before insert or update on public.drivers
  for each row execute function public.drivers_guard();

-- Профиль: роль меняет только админ.
create function public.profiles_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not from_app() or is_admin() then return new; end if;
  if tg_op = 'INSERT' then new.role := 'client';
  else new.role := old.role; end if;
  return new;
end $$;

create trigger profiles_guard before insert or update on public.profiles
  for each row execute function public.profiles_guard();

-- ───────────── Права (RLS) ─────────────

alter table public.profiles enable row level security;
alter table public.regions enable row level security;
alter table public.settings enable row level security;
alter table public.streets enable row level security;
alter table public.places enable row level security;
alter table public.drivers enable row level security;
alter table public.driver_docs enable row level security;
alter table public.orders enable row level security;
alter table public.trips enable row level security;

-- Справочники видят все (в том числе до входа), меняет админ.
create policy read_all on public.regions for select using (true);
create policy read_all on public.settings for select using (true);
create policy read_all on public.streets for select using (true);
create policy read_all on public.places for select using (true);
create policy admin_write on public.regions for all using (is_admin()) with check (is_admin());
create policy admin_write on public.settings for all using (is_admin()) with check (is_admin());
create policy admin_write on public.streets for all using (is_admin()) with check (is_admin());
create policy admin_write on public.places for all using (is_admin()) with check (is_admin());

create policy own_or_staff on public.profiles for select using (id = auth.uid() or is_staff());
create policy own_insert on public.profiles for insert with check (id = auth.uid());
create policy own_update on public.profiles for update using (id = auth.uid() or is_admin());

-- Водитель: свою анкету; админ — все; менеджер — смотреть (назначение заказов);
-- клиент — водителя своего активного заказа (машина на карте).
create policy driver_read on public.drivers for select using (
  id = auth.uid() or is_staff()
  or exists (select 1 from orders o where o.driver_id = drivers.id and o.client_id = auth.uid()
             and o.status in ('accepted','arrived','riding'))
);
create policy driver_insert on public.drivers for insert with check (id = auth.uid() or is_admin());
create policy driver_update on public.drivers for update using (id = auth.uid() or is_admin());
create policy driver_delete on public.drivers for delete using (is_admin());

-- Машины на линии для карты — без телефонов и документов.
create view public.online_drivers as
  select id, region, vehicle, lat, lng, location_at
  from public.drivers
  where status = 'online' and approval = 'approved' and location_at > now() - interval '10 minutes';
grant select on public.online_drivers to anon, authenticated;

create policy docs_own on public.driver_docs for all
  using (driver_id = auth.uid() or is_admin()) with check (driver_id = auth.uid() or is_admin());

-- Заказы: клиент — свои; водитель — свои и ищущие в своём районе; менеджер и админ — все.
create policy order_read on public.orders for select using (
  client_id = auth.uid() or driver_id = auth.uid() or is_staff()
  or (status = 'searching' and is_active_driver() and region = my_driver_region())
);
create policy order_insert on public.orders for insert with check (
  (client_id = auth.uid() and created_by = 'app' and status = 'searching' and driver_id is null and bids = '{}')
  or (is_staff() and created_by = 'manager')
);
create policy order_staff_update on public.orders for update using (is_staff());

-- Рейсы видят все вошедшие (как сейчас в Firestore). TODO: скрыть телефоны чужих пассажиров.
create policy trip_read on public.trips for select using (auth.uid() is not null);
create policy trip_insert on public.trips for insert with check (driver_id = auth.uid() and is_active_driver());
create policy trip_update on public.trips for update using (driver_id = auth.uid() or is_staff());

-- ───────────── Действия с заказом (RPC) ─────────────

-- Водитель берёт заказ; менеджер может назначить водителя (p_driver).
create function public.accept_order(p_order uuid, p_driver uuid default null) returns boolean
language plpgsql security definer set search_path = public as $$
declare d drivers; o orders;
begin
  if p_driver is not null and not is_staff() then raise exception 'forbidden'; end if;
  select * into d from drivers where id = coalesce(p_driver, auth.uid());
  if d.id is null then raise exception 'not a driver'; end if;
  if p_driver is null and not is_active_driver() then raise exception 'driver not active'; end if;
  select * into o from orders where id = p_order for update;
  if o.status <> 'searching' then return false; end if;
  if p_driver is null and o.region <> d.region then raise exception 'other region'; end if;
  update orders set status = 'accepted', driver_id = d.id, driver_name = d.name,
    driver_car = nullif(trim(d.car_color || ' ' || d.car_model), ''), driver_plate = nullif(d.plate, ''),
    accepted_at = now()
  where id = p_order;
  return true;
end $$;

-- Грузовое: водитель предлагает цену.
create function public.place_bid(p_order uuid, p_price integer) returns void
language plpgsql security definer set search_path = public as $$
declare d drivers;
begin
  if not is_active_driver() then raise exception 'driver not active'; end if;
  select * into d from drivers where id = auth.uid();
  update orders set bids = bids || jsonb_build_object(d.id::text, jsonb_build_object(
      'driverName', d.name, 'car', trim(d.car_color || ' ' || d.car_model), 'plate', d.plate,
      'price', p_price, 'at', now()))
  where id = p_order and status = 'searching' and service = 'cargo' and region = d.region;
end $$;

-- Клиент выбирает предложение водителя.
create function public.choose_bid(p_order uuid, p_driver uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare o orders; b jsonb;
begin
  select * into o from orders where id = p_order for update;
  if o.client_id is distinct from auth.uid() and not is_staff() then raise exception 'forbidden'; end if;
  if o.status <> 'searching' then return false; end if;
  b := o.bids -> p_driver::text;
  if b is null then raise exception 'no such bid'; end if;
  update orders set status = 'accepted', driver_id = p_driver, driver_name = b->>'driverName',
    driver_car = b->>'car', driver_plate = b->>'plate', price = (b->>'price')::int, accepted_at = now()
  where id = p_order;
  return true;
end $$;

-- Водитель ведёт поездку: accepted → arrived → riding → done.
create function public.advance_order(p_order uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare o orders;
begin
  select * into o from orders where id = p_order for update;
  if o.driver_id is distinct from auth.uid() then raise exception 'forbidden'; end if;
  if not ((o.status = 'accepted' and p_status = 'arrived')
       or (o.status in ('accepted','arrived') and p_status = 'riding')
       or (o.status = 'riding' and p_status = 'done')) then
    raise exception 'bad transition % -> %', o.status, p_status;
  end if;
  update orders set status = p_status where id = p_order;
end $$;

-- Водитель отказывается от принятого заказа — заказ снова ищет машину.
create function public.release_order(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update orders set status = 'searching', driver_id = null, driver_name = null, driver_car = null,
    driver_plate = null, client_coming_out = false,
    declined_by = array_append(array_remove(declined_by, auth.uid()), auth.uid())
  where id = p_order and driver_id = auth.uid() and status in ('accepted','arrived');
end $$;

-- Клиент (или менеджер) отменяет заказ до начала поездки.
create function public.cancel_order(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update orders set status = 'cancelled'
  where id = p_order and status in ('searching','accepted','arrived')
    and (client_id = auth.uid() or is_staff());
end $$;

create function public.client_coming_out(p_order uuid) returns void
language sql security definer set search_path = public as $$
  update orders set client_coming_out = true where id = p_order and client_id = auth.uid();
$$;

create function public.rate_order(p_order uuid, p_stars smallint) returns void
language sql security definer set search_path = public as $$
  update orders set rating = p_stars where id = p_order and client_id = auth.uid() and status = 'done';
$$;

-- ───────────── Межгород (RPC) ─────────────

create function public.book_seat(p_trip uuid, p_seat int, p_name text, p_phone text) returns boolean
language plpgsql security definer set search_path = public as $$
declare t trips;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  if p_seat not between 1 and 4 then raise exception 'bad seat'; end if;
  select * into t from trips where id = p_trip for update;
  if t.status <> 'open' or t.whole is not null or t.seats ? p_seat::text then return false; end if;
  update trips set seats = seats || jsonb_build_object(p_seat::text,
    jsonb_build_object('clientId', auth.uid(), 'name', p_name, 'phone', p_phone))
  where id = p_trip;
  return true;
end $$;

create function public.cancel_seat(p_trip uuid, p_seat int) returns void
language plpgsql security definer set search_path = public as $$
begin
  update trips set seats = seats - p_seat::text
  where id = p_trip and (seats -> p_seat::text ->> 'clientId' = auth.uid()::text
                         or driver_id = auth.uid() or is_staff());
end $$;

create function public.book_whole(p_trip uuid, p_name text, p_phone text) returns boolean
language plpgsql security definer set search_path = public as $$
declare t trips;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  select * into t from trips where id = p_trip for update;
  if t.status <> 'open' or t.whole is not null or t.seats <> '{}' then return false; end if;
  update trips set whole = jsonb_build_object('clientId', auth.uid(), 'name', p_name, 'phone', p_phone)
  where id = p_trip;
  return true;
end $$;

create function public.cancel_whole(p_trip uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update trips set whole = null
  where id = p_trip and (whole ->> 'clientId' = auth.uid()::text or driver_id = auth.uid() or is_staff());
end $$;

-- Цена посылки берётся из рейса, а не от клиента.
create function public.add_parcel(p_trip uuid, p_sender_name text, p_sender_phone text,
  p_what text, p_to_name text, p_to_phone text) returns text
language plpgsql security definer set search_path = public as $$
declare pid text; t trips;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  select * into t from trips where id = p_trip;
  if t.status <> 'open' then raise exception 'trip closed'; end if;
  pid := auth.uid()::text || '_' || (extract(epoch from clock_timestamp()) * 1000)::bigint;
  update trips set parcels = parcels || jsonb_build_object(pid, jsonb_build_object(
    'clientId', auth.uid(), 'senderName', p_sender_name, 'senderPhone', p_sender_phone,
    'what', p_what, 'toName', p_to_name, 'toPhone', p_to_phone, 'price', t.parcel_price))
  where id = p_trip;
  return pid;
end $$;

create function public.remove_parcel(p_trip uuid, p_parcel text) returns void
language plpgsql security definer set search_path = public as $$
begin
  update trips set parcels = parcels - p_parcel
  where id = p_trip and (parcels -> p_parcel ->> 'clientId' = auth.uid()::text
                         or driver_id = auth.uid() or is_staff());
end $$;

-- RPC доступны только вошедшим.
do $$
declare f text;
begin
  foreach f in array array['accept_order(uuid,uuid)','place_bid(uuid,integer)','choose_bid(uuid,uuid)',
    'advance_order(uuid,text)','release_order(uuid)','cancel_order(uuid)','client_coming_out(uuid)',
    'rate_order(uuid,smallint)','book_seat(uuid,int,text,text)','cancel_seat(uuid,int)',
    'book_whole(uuid,text,text)','cancel_whole(uuid)','add_parcel(uuid,text,text,text,text,text)',
    'remove_parcel(uuid,text)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ───────────── Файлы документов водителей ─────────────

insert into storage.buckets (id, name, public) values ('driver-docs', 'driver-docs', false)
  on conflict (id) do nothing;

create policy driver_docs_own on storage.objects for all to authenticated
  using (bucket_id = 'driver-docs' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()))
  with check (bucket_id = 'driver-docs' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- ───────────── Realtime ─────────────

alter publication supabase_realtime add table
  public.orders, public.drivers, public.trips, public.settings, public.streets, public.places, public.regions;

-- ───────────── Начальные данные ─────────────

insert into public.regions (id, name, lat, lng, radius_km) values
  ('dostyk', 'Достык', 45.2535, 82.4926, 8),
  ('usharal', 'Ушарал', 46.1700, 80.9400, 10)
on conflict (id) do nothing;
