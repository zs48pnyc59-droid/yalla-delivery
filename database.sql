create extension if not exists "pgcrypto";

-- جدول الملفات الشخصية والصلاحيات (مربوط بحسابات Supabase Auth الحقيقية)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null default 'عميل 48',
  phone text,
  city text,
  address text,
  role_slug text not null default 'customer' check (role_slug in ('super_admin', 'admin', 'customer')),
  is_blocked boolean not null default false,
  last_login_at timestamptz default now(),
  created_at timestamptz not null default now()
);

-- إنشاء بروفايل تلقائياً عند تسجيل أي حساب جديد في الموقع
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, email, full_name, phone)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'phone'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- جدول الأقسام
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null,
  name_en text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- جدول المنتجات الحقيقية (يبدأ فارغاً وتضيفه أنت من لوحة الأدمن)
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
  skin_type text default 'جميع أنواع البشرة',
  price numeric(10,2) not null check (price >= 0),
  sale_price numeric(10,2) check (sale_price is null or sale_price >= 0),
  stock_qty int not null default 0 check (stock_qty >= 0),
  badge text,
  image_url text not null,
  status text not null default 'active' check (status in ('active', 'draft')),
  created_at timestamptz not null default now()
);

-- جدول الطلبات
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text unique not null,
  user_id uuid references auth.users(id) on delete set null,
  customer_name text not null,
  customer_email text not null,
  customer_phone text not null,
  shipping_city text not null,
  shipping_address text not null,
  payment_method text not null default 'cod',
  order_status text not null default 'pending' check (order_status in ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled')),
  items jsonb not null default '[]'::jsonb,
  subtotal numeric(12,2) not null,
  discount_amount numeric(12,2) not null default 0,
  shipping_fee numeric(12,2) not null default 0,
  tax_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null,
  created_at timestamptz not null default now()
);

-- جدول الكوبونات
create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  discount_type text not null check (discount_type in ('percent', 'fixed', 'free_shipping')),
  discount_value numeric(10,2) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- جدول إعدادات المتجر والتحكم باللغات من الأدمن
create table if not exists public.store_settings (
  id int primary key default 1 check (id = 1),
  default_lang text not null default 'ar' check (default_lang in ('ar', 'en')),
  enable_ar boolean not null default true,
  enable_en boolean not null default true,
  announcement_ar text not null default 'توصيل سريع مجاني للطلبات فوق $150',
  announcement_en text not null default 'COMPLIMENTARY EXPRESS DELIVERY ON ORDERS OVER $150',
  hero_title_ar text not null default 'إشراقة مصقولة في كل قطرة.',
  hero_title_en text not null default 'Sculpted Radiance in Every Drop.',
  hero_desc_ar text not null default 'تركيبات نباتية فاخرة وإكسير غني بالذهب عيار 24 لبشرة متألقة.',
  hero_desc_en text not null default 'Botanical actives and 24k gold-infused elixirs crafted for enduring luminescence.',
  custom_translations jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- دالة التحقق من صلاحية الأدمن
create or replace function public.is_admin()
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role_slug in ('super_admin', 'admin')
      and is_blocked = false
  );
$$;

-- تفعيل الحماية RLS
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.coupons enable row level security;
alter table public.store_settings enable row level security;

-- سياسات الوصول
create policy "Public read settings" on public.store_settings for select using (true);
create policy "Admins update settings" on public.store_settings for all using (public.is_admin());

create policy "Public read active products" on public.products for select using (status = 'active' or public.is_admin());
create policy "Admins manage products" on public.products for all using (public.is_admin());

create policy "Public read categories" on public.categories for select using (true);
create policy "Admins manage categories" on public.categories for all using (public.is_admin());

create policy "Public read active coupons" on public.coupons for select using (is_active = true or public.is_admin());
create policy "Admins manage coupons" on public.coupons for all using (public.is_admin());

create policy "Users read own profile" on public.profiles for select using (auth.uid() = id or public.is_admin());
create policy "Users update own profile" on public.profiles for update using (auth.uid() = id or public.is_admin());

create policy "Anyone create order" on public.orders for insert with check (true);
create policy "Users view own orders" on public.orders for select using (auth.uid() = user_id or public.is_admin());
create policy "Admins update orders" on public.orders for update using (public.is_admin());

-- إدخال صف الإعدادات الافتراضي فقط (بدون أي منتجات وهمية)
insert into public.store_settings (id) values (1) on conflict (id) do nothing;
