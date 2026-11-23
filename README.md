# 48 COSMETICS — Luxury E-Commerce & Admin Architecture

## Architecture Overview
- `index.html`: Customer storefront with EN/AR + RTL/LTR support, catalog search & filters, quick product details, persistent cart drawer with free-shipping progress & coupon validation, wishlist, and checkout.
- `admin.html`: Separate admin control center displaying authenticated profile metadata, KPI cards, Chart.js analytics, catalog/order/inventory/coupon/activity management, and storefront controls.
- `database.sql`: Normalized PostgreSQL schema, foreign keys, indexes, RLS policies, and initial seed rows for Supabase.
- `config.example.js`: Safe configuration template (uses only the Supabase `anon` key—never `service_role`).

## Setup Steps
1. Create a new project in **Supabase**.
2. Open the **SQL Editor** in Supabase and run `database.sql`.
3. Create an admin user in **Supabase Auth** (`Authentication -> Users`) and insert a matching row in `public.profiles` with `role_slug = 'super_admin'`.
4. Copy `config.example.js` to `config.js` and enter your `url` and `anonKey` (and update `<script src="./config.js"></script>` in `index.html` and `admin.html`).
5. Deploy `index.html`, `admin.html`, `config.js`, and `README.md` to any static host (such as GitHub Pages, Vercel, or Netlify). When Supabase credentials are omitted, both pages automatically run in **Demo Mode** using local sample data.
