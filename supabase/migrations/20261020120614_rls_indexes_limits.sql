-- ============ Индексы ============
create index products_next_check_idx on public.products (next_check_at);
create index products_source_idx on public.products (source);
create index tracked_items_user_idx on public.tracked_items (user_id);
create index tracked_items_product_idx on public.tracked_items (product_id);
create index price_history_product_time_idx on public.price_history (product_id, checked_at desc);
create index notifications_user_time_idx on public.notifications (user_id, created_at desc);
create index notifications_unsent_idx on public.notifications (created_at) where sent_at is null;
create index notification_channels_user_idx on public.notification_channels (user_id);

-- ============ Включаем RLS ============
alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.tracked_items enable row level security;
alter table public.price_history enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_channels enable row level security;
alter table public.source_health enable row level security;
alter table public.worker_heartbeats enable row level security;

-- ============ Права доступа ============
-- Аноним не видит ничего
revoke all on all tables in schema public from anon;

-- Вошедший пользователь: сначала забираем всё, потом выдаём точечно
revoke all on all tables in schema public from authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, theme, timezone, quiet_hours_start, quiet_hours_end)
  on public.profiles to authenticated;

grant select on public.products to authenticated;

grant select, delete on public.tracked_items to authenticated;
grant update (target_price, notify_on_stock, drop_percent, paused)
  on public.tracked_items to authenticated;

grant select on public.price_history to authenticated;

grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;

grant select, delete on public.notification_channels to authenticated;
grant update (enabled) on public.notification_channels to authenticated;

grant select on public.source_health to authenticated;
grant select on public.worker_heartbeats to authenticated;

-- ============ Политики RLS ============
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = auth.uid());
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy products_select_tracked on public.products
  for select to authenticated
  using (exists (
    select 1 from public.tracked_items ti
    where ti.product_id = products.id and ti.user_id = auth.uid()
  ));

create policy tracked_items_select_own on public.tracked_items
  for select to authenticated using (user_id = auth.uid());
create policy tracked_items_update_own on public.tracked_items
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy tracked_items_delete_own on public.tracked_items
  for delete to authenticated using (user_id = auth.uid());

create policy price_history_select_tracked on public.price_history
  for select to authenticated
  using (exists (
    select 1 from public.tracked_items ti
    where ti.product_id = price_history.product_id and ti.user_id = auth.uid()
  ));

create policy notifications_select_own on public.notifications
  for select to authenticated using (user_id = auth.uid());
create policy notifications_update_own on public.notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy channels_select_own on public.notification_channels
  for select to authenticated using (user_id = auth.uid());
create policy channels_update_own on public.notification_channels
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy channels_delete_own on public.notification_channels
  for delete to authenticated using (user_id = auth.uid());

create policy source_health_select_all on public.source_health
  for select to authenticated using (true);
create policy worker_heartbeats_select_all on public.worker_heartbeats
  for select to authenticated using (true);

-- ============ Лимит товаров на пользователя ============
create function public.enforce_item_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_max integer;
  v_count integer;
begin
  select max_items into v_max from public.profiles where id = new.user_id;
  select count(*) into v_count from public.tracked_items where user_id = new.user_id;
  if v_count >= coalesce(v_max, 50) then
    raise exception 'items_limit_reached' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger tracked_items_limit
  before insert on public.tracked_items
  for each row execute function public.enforce_item_limit();

-- ============ Добавление товара ============
create function public.add_tracked_item(
  p_url text,
  p_target_price numeric default null,
  p_notify_on_stock boolean default false,
  p_drop_percent numeric default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text := btrim(p_url);
  v_host text;
  v_source text;
  v_product_id uuid;
  v_item_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  if v_url !~* '^https?://[^/?#\s]+' or length(v_url) > 2000
     or v_url ~* '^https?://[^/?#]*@' then
    raise exception 'invalid_url';
  end if;

  v_host := lower(substring(v_url from '^[hH][tT][tT][pP][sS]?://([^/:?#\s]+)'));

  v_source := case
    when v_host ~ '(^|\.)wildberries\.ru$' then 'wildberries'
    when v_host ~ '(^|\.)market\.yandex\.ru$' then 'yandex_market'
    when v_host ~ '(^|\.)ozon\.ru$' then 'ozon'
    when v_host ~ '(^|\.)avito\.ru$' then 'avito'
    else 'jsonld'
  end;

  insert into public.products (url, source)
  values (v_url, v_source)
  on conflict (url) do nothing;

  select id into v_product_id from public.products where url = v_url;

  select id into v_item_id
  from public.tracked_items
  where user_id = auth.uid() and product_id = v_product_id;

  if v_item_id is null then
    insert into public.tracked_items (user_id, product_id, target_price, notify_on_stock, drop_percent)
    values (auth.uid(), v_product_id, p_target_price, p_notify_on_stock, p_drop_percent)
    returning id into v_item_id;
  else
    update public.tracked_items
    set target_price = p_target_price,
        notify_on_stock = p_notify_on_stock,
        drop_percent = p_drop_percent,
        paused = false
    where id = v_item_id;
  end if;

  return v_item_id;
end;
$$;

revoke execute on function public.add_tracked_item(text, numeric, boolean, numeric) from public, anon;
grant execute on function public.add_tracked_item(text, numeric, boolean, numeric) to authenticated;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.enforce_item_limit() from public, anon, authenticated;