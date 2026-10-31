-- Своя цена поездки к ориентиру или от него (например, ТЛЦ — 2 000 ₸). null — обычная цена района.
alter table public.places add column if not exists price integer check (price is null or price >= 0);
