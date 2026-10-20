-- Профили пользователей (1 к 1 с auth.users)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  theme text not null default 'system' check (theme in ('system', 'light', 'dark')),
  timezone text not null default 'Europe/Moscow',
  quiet_hours_start time,
  quiet_hours_end time,
  max_items integer not null default 50 check (max_items >= 0),
  created_at timestamptz not null default now()
);

-- Товары (общие для всех пользователей, расписание проверок тут)
create table public.products (
  id uuid primary key default gen_random_uuid(),
  url text not null unique,
  source text not null check (source in ('wildberries', 'jsonld', 'yandex_market', 'ozon', 'avito')),
  title text,
  image_url text,
  currency text not null default 'RUB',
  last_price numeric(12, 2),
  in_stock boolean,
  last_checked_at timestamptz,
  next_check_at timestamptz not null default now(),
  lease_until timestamptz,
  fail_count integer not null default 0,
  last_error text,
  created_at timestamptz not null default now()
);

-- Что и на каких условиях отслеживает пользователь
create table public.tracked_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  target_price numeric(12, 2) check (target_price > 0),
  notify_on_stock boolean not null default false,
  drop_percent numeric(5, 2) check (drop_percent > 0 and drop_percent < 100),
  paused boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, product_id)
);

-- История цен
create table public.price_history (
  id bigint generated always as identity primary key,
  product_id uuid not null references public.products(id) on delete cascade,
  price numeric(12, 2),
  in_stock boolean,
  currency text not null default 'RUB',
  checked_at timestamptz not null default now()
);

-- Уведомления (dedupe_key защищает от дублей)
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  tracked_item_id uuid references public.tracked_items(id) on delete set null,
  product_id uuid references public.products(id) on delete set null,
  type text not null check (type in ('price_below', 'back_in_stock', 'price_drop_percent', 'system')),
  title text not null,
  body text,
  old_price numeric(12, 2),
  new_price numeric(12, 2),
  dedupe_key text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  sent_at timestamptz,
  unique (user_id, dedupe_key)
);

-- Каналы доставки (пока только Telegram)
create table public.notification_channels (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null default 'telegram' check (type in ('telegram')),
  chat_id bigint unique,
  link_token text unique,
  link_token_expires_at timestamptz,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  unique (user_id, type)
);

-- Здоровье источников (circuit breaker)
create table public.source_health (
  source text primary key check (source in ('wildberries', 'jsonld', 'yandex_market', 'ozon', 'avito')),
  status text not null default 'ok' check (status in ('ok', 'degraded', 'down')),
  consecutive_failures integer not null default 0,
  circuit_open_until timestamptz,
  last_success_at timestamptz,
  last_error text,
  updated_at timestamptz not null default now()
);

insert into public.source_health (source) values
  ('wildberries'), ('jsonld'), ('yandex_market'), ('ozon'), ('avito');

-- Пульс воркеров
create table public.worker_heartbeats (
  worker_id text primary key,
  kind text not null check (kind in ('edge', 'github_actions', 'pc')),
  adapters text[] not null default '{}',
  info jsonb not null default '{}',
  last_seen_at timestamptz not null default now()
);

-- Автосоздание профиля при регистрации
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();