create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null default 'عميل 48',
  phone text,
  city text,
  village text,
  address text,
  role_slug text not null default 'customer' check (role_slug in ('super_admin', 'admin', 'customer')),
  is_blocked boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  sku text unique not null,
  category_name text not null,
  name_ar text not null,
  name_en text not null,
  desc_ar text,
  desc_en text,
  ingredients text,
  usage_instructions text,
  price numeric(10,2) not null check (price >= 0),
  sale_price numeric(10,2),
  cost_price numeric(10,2) default 0,
  stock_qty int not null default 0,
  badge text,
  image_url text not null,
  status text not null default 'active',
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text unique not null,
  user_id uuid references auth.users(id) on delete set null,
  customer_name text not null,
  customer_email text not null,
  customer_phone text not null,
  shipping_city text not null,
  shipping_village text not null,
  shipping_address text not null,
  payment_method text not null default 'cod',
  order_status text not null default 'pending',
  items jsonb not null default '[]'::jsonb,
  subtotal numeric(12,2) not null,
  discount_amount numeric(12,2) not null default 0,
  shipping_fee numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null,
  currency_code text not null default 'ILS',
  created_at timestamptz not null default now()
);

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  ticket_number text unique not null,
  user_id uuid references auth.users(id) on delete cascade,
  customer_name text not null,
  customer_email text not null,
  subject text not null,
  status text not null default 'open' check (status in ('open', 'replied', 'closed')),
  messages jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  discount_type text not null,
  discount_value numeric(10,2) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.store_settings (
  id int primary key default 1 check (id = 1),
  store_status text not null default 'live' check (store_status in ('live', 'maintenance', 'outage', 'updating')),
  status_message_ar text not null default 'نعمل حالياً على تحديث المتجر لخدمتكم بشكل أفضل، سنعود خلال دقائق.',
  status_message_en text not null default 'We are currently updating the store. Back shortly.',
  currency_code text not null default 'ILS',
  currency_symbol text not null default '₪',
  currency_rate numeric(10,4) not null default 1.0000,
  primary_gold text not null default '#d4af37',
  bg_primary text not null default '#070709',
  bg_card text not null default '#14141b',
  text_primary text not null default '#f8f5ef',
  default_lang text not null default 'ar',
  enable_ar boolean not null default true,
  enable_en boolean not null default true,
  announcement_ar text not null default 'توصيل سريع لجميع مدن وقرى ومخيمات الضفة الغربية 🇵🇸',
  announcement_en text not null default 'Express Delivery Across All West Bank Cities, Towns & Camps',
  hero_title_ar text not null default 'جمال فلسطيني أصيل بلمسة ملكية.',
  hero_title_en text not null default 'Authentic Beauty with a Royal Touch.',
  hero_desc_ar text not null default 'مستحضرات عناية فاخرة مصممة بعناية لتمنحك إشراقة تدوم في كل لحظة.',
  hero_desc_en text not null default 'Luxury beauty formulations crafted for lasting radiance.',
  shipping_west_bank_fee numeric(10,2) not null default 20.00,
  free_shipping_min numeric(10,2) not null default 250.00,
  updated_at timestamptz not null default now()
);

insert into public.store_settings (id) values (1) on conflict (id) do nothing;
