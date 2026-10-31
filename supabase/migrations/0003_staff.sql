-- Сотрудники: админ добавляет номер менеджера (или второго админа) прямо в админке.
-- Если человек уже входил — роль ставится сразу, если нет — при первом входе с этого номера.

-- Номер без +7 / 8 и пробелов: последние 10 цифр.
create function public.phone_key(p text) returns text
language sql immutable as $$
  select right(regexp_replace(coalesce(p, ''), '\D', '', 'g'), 10)
$$;

create table public.staff_invites (
  phone text primary key,          -- phone_key(...)
  role text not null check (role in ('manager','admin')),
  name text not null default '',
  created_at timestamptz not null default now()
);
alter table public.staff_invites enable row level security;
create policy admin_all on public.staff_invites for all using (is_admin()) with check (is_admin());

-- Уже назначенные сотрудники — в список.
insert into public.staff_invites (phone, role, name)
select phone_key(u.phone), p.role, p.name
from public.profiles p join auth.users u on u.id = p.id
where p.role in ('manager','admin') and phone_key(u.phone) <> ''
on conflict do nothing;

-- Новый профиль: роль из приглашения по проверенному номеру входа (auth.users), иначе клиент.
create or replace function public.profiles_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not from_app() or is_admin() then return new; end if;
  if tg_op = 'INSERT' then
    new.role := coalesce((
      select i.role from staff_invites i join auth.users u on phone_key(u.phone) = i.phone
      where u.id = new.id), 'client');
  else new.role := old.role; end if;
  return new;
end $$;

-- Добавить / изменить сотрудника. p_role = 'client' — убрать доступ к админке.
create function public.set_staff(p_phone text, p_role text, p_name text default '')
returns void language plpgsql security definer set search_path = public as $$
declare k text := phone_key(p_phone);
begin
  if not is_admin() then raise exception 'forbidden'; end if;
  if length(k) <> 10 then raise exception 'bad-phone'; end if;
  if p_role not in ('manager','admin','client') then raise exception 'bad-role'; end if;
  -- Себя не понижаем — иначе можно остаться без админа.
  if exists (select 1 from auth.users u where u.id = auth.uid() and phone_key(u.phone) = k) then
    raise exception 'self';
  end if;
  if p_role = 'client' then
    delete from staff_invites where phone = k;
    update profiles set role = 'client'
      where role in ('manager','admin') and id in (select id from auth.users where phone_key(phone) = k);
  else
    insert into staff_invites (phone, role, name) values (k, p_role, coalesce(p_name, ''))
      on conflict (phone) do update set role = excluded.role,
        name = case when excluded.name = '' then staff_invites.name else excluded.name end;
    update profiles set role = p_role
      where id in (select id from auth.users where phone_key(phone) = k);
  end if;
end $$;

-- Список сотрудников: вошёл ли уже человек и под каким именем.
create function public.staff_list()
returns table (phone text, role text, name text, joined boolean)
language sql stable security definer set search_path = public as $$
  select i.phone, i.role,
         coalesce(nullif(p.name, ''), i.name),
         p.id is not null
  from staff_invites i
  left join auth.users u on phone_key(u.phone) = i.phone
  left join profiles p on p.id = u.id
  where is_admin()
  order by i.role, i.created_at
$$;

grant execute on function public.set_staff(text, text, text) to authenticated;
grant execute on function public.staff_list() to authenticated;
