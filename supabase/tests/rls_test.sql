\set ON_ERROR_STOP 0
begin;
insert into auth.users (id, phone, aud, role) values
  ('00000000-0000-0000-0000-00000000000c', '77770000000', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000000d', '77770000001', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-00000000000a', '77770000002', 'authenticated', 'authenticated');
insert into profiles (id, name, role) values ('00000000-0000-0000-0000-00000000000a', 'Админ', 'admin');

create function pg_temp.as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;

-- Клиент: профиль с попыткой стать админом, заказ.
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
insert into profiles (id, name, role) values ('00000000-0000-0000-0000-00000000000c', 'Клиент', 'admin');
select 'client role after insert: ' || role from profiles where id = auth.uid();
insert into orders (id, client_id, region, from_label, to_label, price)
  values ('10000000-0000-0000-0000-000000000001', auth.uid(), 'dostyk', 'Вокзал', 'Школа', 500);
select 'client sees own orders: ' || count(*) from orders;

-- Водитель: анкета с попыткой самоодобрения.
select pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
insert into drivers (id, name, region, approval, subscription_until)
  values (auth.uid(), 'Водитель', 'dostyk', 'approved', now() + interval '1 year');
select 'driver approval after insert: ' || approval || ', sub=' || coalesce(subscription_until::text, 'null') from drivers where id = auth.uid();
select 'unapproved driver sees orders: ' || count(*) from orders;
savepoint s1;
select 'unapproved accept: ' || coalesce(accept_order('10000000-0000-0000-0000-000000000001')::text, 'null');
rollback to savepoint s1;

-- Админ одобряет.
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
update drivers set approval = 'approved', subscription_until = now() + interval '90 days', approved_at = now()
  where id = '00000000-0000-0000-0000-00000000000d';
select 'admin sees drivers: ' || count(*) from drivers;

-- Водитель берёт и ведёт заказ.
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
update drivers set status = 'online', lat = 45.25, lng = 82.49, location_at = now() where id = auth.uid();
select 'approved driver sees searching: ' || count(*) from orders;
select 'accept: ' || accept_order('10000000-0000-0000-0000-000000000001');
select 'accept again: ' || accept_order('10000000-0000-0000-0000-000000000001');
select advance_order('10000000-0000-0000-0000-000000000001', 'arrived');
select advance_order('10000000-0000-0000-0000-000000000001', 'riding');
select advance_order('10000000-0000-0000-0000-000000000001', 'done');
select 'status: ' || status from orders where id = '10000000-0000-0000-0000-000000000001';
update drivers set subscription_until = now() + interval '10 years' where id = auth.uid();
select 'driver sub still ~90d: ' || (subscription_until < now() + interval '100 days') from drivers where id = auth.uid();
update orders set price = 1 where id = '10000000-0000-0000-0000-000000000001';
select 'price after direct update: ' || price from orders where id = '10000000-0000-0000-0000-000000000001';

-- Клиент видит водителя своего заказа и машины на линии; рейс и бронь.
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select 'client sees driver: ' || count(*) from drivers;
select 'online cars: ' || count(*) from online_drivers;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
insert into trips (id, driver_id, from_region, to_region, date, time, seat_price, parcel_price)
  values ('20000000-0000-0000-0000-000000000001', auth.uid(), 'dostyk', 'usharal', current_date, '09:00', 3500, 1500);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select 'book seat 2: ' || book_seat('20000000-0000-0000-0000-000000000001', 2, 'Клиент', '+77770000000');
select 'book seat 2 again: ' || book_seat('20000000-0000-0000-0000-000000000001', 2, 'Другой', '+7');
select 'book whole when seat taken: ' || book_whole('20000000-0000-0000-0000-000000000001', 'Клиент', '+7');
select 'parcel id prefix ok: ' || (add_parcel('20000000-0000-0000-0000-000000000001', 'А', '+7', 'сумка', 'Б', '+7') like '0000%');
select 'parcel price from trip: ' || (parcels -> (select k from jsonb_object_keys(parcels) k limit 1) ->> 'price') from trips;
rollback;
