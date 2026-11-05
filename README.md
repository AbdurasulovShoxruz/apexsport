# APEX SPORT: Telegram Mini App store

Men's sportswear shop that runs inside Telegram, with delivery orders, a live admin panel and a staff Telegram group.

- `index.html`   the shop (Uzbek / Russian)
- `admin/`       admin panel at `/admin` (orders, products, stock, promo codes, analytics, broadcast)
- `api/`         Vercel serverless functions (bot webhook, orders, admin)
- `lib/`         shared code; `lib/catalog.js` = server price list
- `config.js`    brand name, phone, address, hours, map point, delivery fees
- `supabase.sql` the whole database in ONE file
- `supabase-shoes.sql` adds the Shoes category to an existing database
- `covers/`      category cover photos
- `.env.example` every environment variable you need
- `DEPLOY.md`    step-by-step deploy guide (start here)
- `avatar.png`   bot profile picture, `logo.png` logo

`npm test` runs the automated checks (no accounts needed).
Without the backend the shop still opens in demo mode (no orders are saved).
