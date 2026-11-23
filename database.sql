-- 48 COSMETICS — PostgreSQL / Supabase Schema, RLS & Seed Data
create extension if not exists "pgcrypto";

-- Helper: update updated_at timestamp
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Profiles & Roles
create table if not exists public.admin_roles (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  level int not null default 10,
  created_at timestamptz not null default now()
);

create table if not exists public.admin_permissions (
  id uuid primary key default gen_random_uuid(),
  role_id uuid not null references public.admin_roles(id) on delete cascade,
  module_key text not null,
  can_read boolean not null default true,
  can_write boolean not null default false,
  can_delete boolean not null default false,
  unique(role_id, module_key)
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  username text unique,
  display_name text not null default 'Guest',
  avatar_url text,
  phone text,
  preferred_lang text not null default 'en' check (preferred_lang in ('en', 'ar')),
  role_slug text not null default 'customer',
  is_blocked boolean not null default false,
  last_login_at timestamptz,
  last_activity_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Catalog
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.categories(id) on delete set null,
  slug text unique not null,
  name_en text not null,
  name_ar text not null,
  description_en text,
  description_ar text,
  image_url text,
  banner_url text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.brands (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  logo_url text,
  description text,
  is_visible boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  sku text unique not null,
  barcode text,
  slug text unique not null,
  category_id uuid references public.categories(id) on delete set null,
  brand_id uuid references public.brands(id) on delete set null,
  name_en text not null,
  name_ar text not null,
  short_desc_en text,
  short_desc_ar text,
  description_en text,
  description_ar text,
  ingredients text,
  usage_instructions text,
  skin_type text default 'All Skin Types',
  product_type text default 'Luxury',
  price numeric(10,2) not null check (price >= 0),
  sale_price numeric(10,2) check (sale_price is null or sale_price >= 0),
  cost_price numeric(10,2) not null default 0 check (cost_price >= 0),
  badge text,
  rating numeric(3,2) not null default 5.00,
  review_count int not null default 0,
  is_featured boolean not null default false,
  is_bestseller boolean not null default false,
  is_new boolean not null default true,
  is_trending boolean not null default false,
  status text not null default 'active' check (status in ('active', 'draft', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  title text not null,
  size_label text,
  color_name text,
  color_hex text,
  price_delta numeric(10,2) not null default 0,
  sku_suffix text,
  created_at timestamptz not null default now()
);

create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  url text not null,
  alt_text text,
  is_primary boolean not null default false,
  sort_order int not null default 0
);

-- Inventory & Suppliers
create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact_email text,
  phone text,
  country text,
  created_at timestamptz not null default now()
);

create table if not exists public.inventory (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null unique references public.products(id) on delete cascade,
  warehouse_name text not null default 'Main Vault',
  stock_qty int not null default 0 check (stock_qty >= 0),
  reserved_qty int not null default 0 check (reserved_qty >= 0),
  low_stock_threshold int not null default 8,
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  delta int not null,
  reason text not null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  po_number text unique not null,
  supplier_id uuid references public.suppliers(id) on delete set null,
  status text not null default 'ordered' check (status in ('draft', 'ordered', 'received', 'cancelled')),
  total_cost numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

-- Customers, Addresses, Cart, Wishlist
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid unique references public.profiles(id) on delete set null,
  full_name text not null,
  email text not null,
  phone text,
  segment text not null default 'new' check (segment in ('vip', 'new', 'active', 'inactive')),
  total_orders int not null default 0,
  total_spent numeric(12,2) not null default 0,
  notes text,
  is_blocked boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  label text default 'Home',
  city text not null,
  line1 text not null,
  delivery_notes text,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.cart_items (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  variant_id uuid references public.product_variants(id) on delete set null,
  qty int not null default 1 check (qty > 0),
  created_at timestamptz not null default now(),
  unique(profile_id, product_id, variant_id)
);

create table if not exists public.wishlists (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(profile_id, product_id)
);

-- Shipping, Coupons, Promotions, Orders, Payments
create table if not exists public.shipping_zones (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  cities text[] not null default '{}',
  estimated_days text not null default '1-3 business days',
  is_active boolean not null default true
);

create table if not exists public.shipping_rates (
  id uuid primary key default gen_random_uuid(),
  zone_id uuid not null references public.shipping_zones(id) on delete cascade,
  label text not null,
  rate numeric(10,2) not null default 0,
  free_above numeric(10,2)
);

create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  discount_type text not null check (discount_type in ('percentage', 'fixed', 'free_shipping')),
  discount_value numeric(10,2) not null default 0,
  min_order_value numeric(10,2) not null default 0,
  usage_limit int,
  used_count int not null default 0,
  expires_at timestamptz,
  is_active boolean not null default true
);

create table if not exists public.promotions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  promo_type text not null default 'flash_sale',
  discount_percent numeric(5,2) not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text unique not null,
  customer_id uuid references public.customers(id) on delete set null,
  customer_name text not null,
  customer_email text not null,
  customer_phone text not null,
  shipping_city text not null,
  shipping_address text not null,
  delivery_notes text,
  payment_method text not null default 'cod' check (payment_method in ('cod', 'card_gateway', 'bank_transfer')),
  payment_status text not null default 'pending_confirmation' check (payment_status in ('pending_confirmation', 'paid', 'refunded', 'failed')),
  order_status text not null default 'pending' check (order_status in ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')),
  tracking_number text,
  coupon_code text,
  subtotal numeric(12,2) not null,
  discount_amount numeric(12,2) not null default 0,
  shipping_fee numeric(12,2) not null default 0,
  tax_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null,
  internal_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  variant_title text,
  unit_price numeric(10,2) not null,
  qty int not null check (qty > 0),
  line_total numeric(12,2) not null
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  provider text not null,
  provider_reference text,
  amount numeric(12,2) not null,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

-- Reviews, Support, CMS, Logs, Settings
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  author_name text not null,
  rating int not null check (rating between 1 and 5),
  comment text not null,
  admin_reply text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  subject text not null,
  customer_email text not null,
  message text not null,
  status text not null default 'open' check (status in ('open', 'in_progress', 'resolved', 'closed')),
  created_at timestamptz not null default now()
);

create table if not exists public.contact_messages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  phone text,
  message text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.newsletter_subscribers (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  actor_email text,
  action text not null,
  entity text not null,
  details jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  table_name text not null,
  record_id text,
  operation text not null,
  diff jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.store_settings (
  id int primary key default 1 check (id = 1),
  store_name text not null default '48 COSMETICS',
  announcement_en text not null default 'COMPLIMENTARY EXPRESS DELIVERY ON ORDERS OVER $150',
  announcement_ar text not null default 'توصيل سريع مجاني للطلبات فوق $150',
  maintenance_mode boolean not null default false,
  currency_code text not null default 'USD',
  currency_symbol text not null default '$',
  tax_rate numeric(5,4) not null default 0.0500,
  updated_at timestamptz not null default now()
);

create table if not exists public.website_sections (
  id uuid primary key default gen_random_uuid(),
  section_key text unique not null,
  title_en text,
  title_ar text,
  subtitle_en text,
  subtitle_ar text,
  image_url text,
  is_visible boolean not null default true,
  updated_at timestamptz not null default now()
);

-- Indexes
create index if not exists idx_products_category on public.products(category_id);
create index if not exists idx_products_status on public.products(status);
create index if not exists idx_orders_status on public.orders(order_status);
create index if not exists idx_orders_created on public.orders(created_at desc);
create index if not exists idx_reviews_product_status on public.reviews(product_id, status);
create index if not exists idx_activity_logs_created on public.activity_logs(created_at desc);

-- Triggers
drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_categories_updated on public.categories;
create trigger trg_categories_updated before update on public.categories
for each row execute function public.set_updated_at();

drop trigger if exists trg_products_updated on public.products;
create trigger trg_products_updated before update on public.products
for each row execute function public.set_updated_at();

drop trigger if exists trg_orders_updated on public.orders;
create trigger trg_orders_updated before update on public.orders
for each row execute function public.set_updated_at();

-- Helper function to check admin role
create or replace function public.is_admin()
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role_slug in ('super_admin', 'admin', 'manager', 'staff')
      and coalesce(is_blocked, false) = false
  );
$$;

-- Enable RLS
alter table public.profiles enable row level security;
alter table public.admin_roles enable row level security;
alter table public.admin_permissions enable row level security;
alter table public.categories enable row level security;
alter table public.brands enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.product_images enable row level security;
alter table public.inventory enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.suppliers enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.customers enable row level security;
alter table public.addresses enable row level security;
alter table public.cart_items enable row level security;
alter table public.wishlists enable row level security;
alter table public.shipping_zones enable row level security;
alter table public.shipping_rates enable row level security;
alter table public.coupons enable row level security;
alter table public.promotions enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.reviews enable row level security;
alter table public.support_tickets enable row level security;
alter table public.contact_messages enable row level security;
alter table public.newsletter_subscribers enable row level security;
alter table public.notifications enable row level security;
alter table public.activity_logs enable row level security;
alter table public.audit_logs enable row level security;
alter table public.store_settings enable row level security;
alter table public.website_sections enable row level security;

-- Public read policies for storefront
create policy "Public read active categories" on public.categories for select using (is_active = true or public.is_admin());
create policy "Public read visible brands" on public.brands for select using (is_visible = true or public.is_admin());
create policy "Public read active products" on public.products for select using (status = 'active' or public.is_admin());
create policy "Public read variants" on public.product_variants for select using (true);
create policy "Public read images" on public.product_images for select using (true);
create policy "Public read inventory qty" on public.inventory for select using (true);
create policy "Public read shipping zones" on public.shipping_zones for select using (is_active = true or public.is_admin());
create policy "Public read shipping rates" on public.shipping_rates for select using (true);
create policy "Public read active promotions" on public.promotions for select using (is_active = true or public.is_admin());
create policy "Public read store settings" on public.store_settings for select using (true);
create policy "Public read website sections" on public.website_sections for select using (is_visible = true or public.is_admin());
create policy "Public read approved reviews" on public.reviews for select using (status = 'approved' or public.is_admin());

-- Public / customer insert policies
create policy "Anyone can submit review" on public.reviews for insert with check (status = 'pending');
create policy "Anyone can subscribe newsletter" on public.newsletter_subscribers for insert with check (true);
create policy "Anyone can send contact message" on public.contact_messages for insert with check (true);
create policy "Anyone can create support ticket" on public.support_tickets for insert with check (true);
create policy "Anyone can create order" on public.orders for insert with check (payment_status in ('pending_confirmation', 'failed'));
create policy "Anyone can create order items" on public.order_items for insert with check (true);

-- User own records policies
create policy "Users view own profile" on public.profiles for select using (auth.uid() = id or public.is_admin());
create policy "Users update own profile" on public.profiles for update using (auth.uid() = id or public.is_admin());
create policy "Users manage own wishlist" on public.wishlists for all using (auth.uid() = profile_id or public.is_admin()) with check (auth.uid() = profile_id or public.is_admin());
create policy "Users manage own cart" on public.cart_items for all using (auth.uid() = profile_id or public.is_admin()) with check (auth.uid() = profile_id or public.is_admin());

-- Admin full management policies
create policy "Admins manage categories" on public.categories for all using (public.is_admin()) with check (public.is_admin());
create policy "Admins manage brands" on public.brands for all using (public.is_admin()) with check (public.is_admin());
create policy "Admins manage products" on public.products for all using (public.is_admin()) with check (public.is_admin());
create policy "Admins manage inventory" on public.inventory for all using (public.is_admin()) with check (public.is_admin());
create policy "Admins manage orders" on public.orders for select using (public.is_admin());
create policy "Admins update orders" on public.orders for update using (public.is_admin()) with check (public.is_admin());
create policy "Admins view order items" on public.order_items for select using (public.is_admin());
create policy "Admins manage customers" on public.customers for all using (public.is_admin()) with check (public.is_admin());
create policy "Admins manage coupons" on public.coupons for all using (public.is_admin()) with check (public.is_admin());
create policy "Admins manage promotions" on public.promotions for all using (public.is_admin()) with check (public.is_admin());
create policy "Admins manage reviews" on public.reviews for update using (public.is_admin()) with check (public.is_admin());
create policy "Admins delete reviews" on public.reviews for delete using (public.is_admin());
create policy "Admins manage settings" on public.store_settings for all using (public.is_admin()) with check (public.is_admin());
create policy "Admins manage sections" on public.website_sections for all using (public.is_admin()) with check (public.is_admin());
create policy "Admins read logs" on public.activity_logs for select using (public.is_admin());
create policy "Admins insert logs" on public.activity_logs for insert with check (public.is_admin() or auth.uid() is not null);

-- Seed initial roles & settings
insert into public.admin_roles (slug, name, level) values
  ('super_admin', 'Super Administrator', 100),
  ('admin', 'Store Director', 80),
  ('manager', 'Operations Manager', 60),
  ('staff', 'Support & Fulfillment', 30)
on conflict (slug) do nothing;

insert into public.store_settings (id) values (1) on conflict (id) do nothing;
