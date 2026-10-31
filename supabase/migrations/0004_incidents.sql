-- SOS и жалобы: клиент нажал «Помощь» в поездке, пожаловался после поездки, водитель — на клиента.
create table public.incidents (
  id uuid primary key default gen_random_uuid(),
  region text not null default 'dostyk',
  kind text not null check (kind in ('sos','complaint','review')),
  title text not null default '',
  body text not null default '',
  order_id uuid references public.orders on delete set null,
  author_id uuid default auth.uid() references auth.users on delete set null,
  author_name text not null default '',
  author_phone text not null default '',
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index incidents_region on public.incidents (region, created_at desc);

-- Имя и номер автора берём из профиля и номера входа, а не из того, что прислало приложение.
create function public.incidents_fill() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not from_app() then return new; end if;
  if tg_op = 'INSERT' then
    new.author_id := auth.uid();
    new.author_name := coalesce((select name from profiles where id = auth.uid()), '');
    new.author_phone := coalesce((select '+' || phone from auth.users where id = auth.uid()), '');
    new.created_at := now();
    new.resolved_at := null;
  end if;
  return new;
end $$;
create trigger incidents_fill before insert on public.incidents
  for each row execute function public.incidents_fill();

alter table public.incidents enable row level security;
create policy own_insert on public.incidents for insert with check (auth.uid() is not null);
create policy own_or_staff on public.incidents for select using (author_id = auth.uid() or is_staff());
create policy staff_update on public.incidents for update using (is_staff());
create policy admin_delete on public.incidents for delete using (is_admin());

alter publication supabase_realtime add table public.incidents;
