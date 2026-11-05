# APEX SPORT: deploy guide (about 30 minutes)

You need free accounts on GitHub, Supabase and Vercel, plus a Telegram bot from @BotFather.
Do the parts in order. Replace `apex-sport` with your own names where you chose different ones.

---

## 1. Bot (Telegram)

1. In Telegram open **@BotFather** -> `/newbot` -> name `APEX SPORT`, username like `apexsport_uz_bot`.
2. Copy the **token** (looks like `123456789:AA...`). Keep it secret.
3. `/setuserpic` -> choose your bot -> send `avatar.png` from this folder.

## 2. Supabase (database)

1. supabase.com -> **New project** -> name `apex-sport`, set a database password, pick the closest region -> Create.
2. When ready: **SQL Editor -> New query**, open `supabase.sql`, copy ALL of it, paste, click **Run**. It says "Success". This creates every table, the stock functions, the photo storage bucket and 16 demo products. (Safe to run twice.)
3. **Project Settings -> API** (or API Keys). Copy:
   - **Project URL** -> this is `SUPABASE_URL`
   - the **secret key** (`service_role` on the Legacy tab, or `sb_secret_...`) -> this is `SUPABASE_SERVICE_KEY`

The secret key gives full access to your data. It goes only into Vercel, never into GitHub or `index.html`.

## 3. GitHub

1. github.com -> **New repository** -> name `apex-sport` (Private is fine) -> Create.
2. In Terminal, inside this project folder:

```
git init
git add .
git commit -m "APEX SPORT"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/apex-sport.git
git push -u origin main
```

(`.env` files are ignored by `.gitignore`, so secrets are never uploaded.)

## 4. Vercel

1. vercel.com -> **Add New -> Project** -> import the `apex-sport` repo.
2. Framework Preset: **Other**. Leave Build/Output settings empty. Do not deploy yet: open **Environment Variables** first.
3. Add these (all environments ticked). The full list with comments is in `.env.example`:

| Name | Value |
|---|---|
| `BOT_TOKEN` | token from BotFather |
| `SUPABASE_URL` | Project URL from step 2 |
| `SUPABASE_SERVICE_KEY` | secret key from step 2 |
| `WEBHOOK_SECRET` | long random text: run `openssl rand -hex 20` |
| `ADMIN_PASSWORD` | strong password for `/admin` |
| `STAFF_CHAT_ID` | add later in step 6 |

4. Click **Deploy**. When it shows **Ready**, note your address, for example `https://apex-sport.vercel.app`.

## 5. Connect the bot to the server (webhook)

Run in Terminal (secret must equal `WEBHOOK_SECRET`; change the URL to yours):

```
export BOT_TOKEN="PASTE_BOT_TOKEN"
export WEBHOOK_SECRET="PASTE_SAME_SECRET_AS_IN_VERCEL"

curl -s "https://api.telegram.org/bot$BOT_TOKEN/setWebhook" \
  -d "url=https://apex-sport.vercel.app/api/bot" \
  -d "secret_token=$WEBHOOK_SECRET" \
  -d 'allowed_updates=["message","callback_query"]'
```

You must see `"ok":true`. Then open the bot in BotFather: `/newapp` (or **Bot Settings -> Menu Button**) and set the Mini App / menu button URL to `https://apex-sport.vercel.app/`.

## 6. Staff group for orders

1. Create a Telegram group `APEX Orders`, add your staff and your bot, make the bot an **admin**.
2. Send `/chatid` in the group. The bot answers `Chat ID: -100...`.
3. Vercel -> Settings -> Environment Variables -> add `STAFF_CHAT_ID` with that number (with the minus).
4. **Deployments -> ... -> Redeploy** (variables only apply to new deployments).

## 7. Test

1. Open the bot, `/start`, press **Raqamni yuborish** (share number). You get "Raqamingiz tasdiqlandi".
2. Open the shop: no "Demo rejim" banner. Add a product, checkout, pick the map point, order.
3. The order appears in the staff group with the map pin and buttons (Qabul qilish, Yo'lda, Yetkazildi, Bekor qilish); the customer is notified.
4. Open `https://apex-sport.vercel.app/admin`, sign in with `ADMIN_PASSWORD`.

## Admin panel: what you can do

- **Overview / Analytics**: today's orders, revenue, 7-day chart, top products, regions, repeat customers.
- **Orders**: change status (customer is notified in the bot), courier name, BTS tracking for regions.
- **Products**: add, edit, price, discount %, stock (also per size), colours, visibility, up to 3 photos per product (**+ Photo**, or **+ Link** from Unsplash/Pexels), "New" flag.
- **Colours / Sections**: edit the colour list and the shop categories (T-shirts, Hoodies, Shorts, Tracksuits, Accessories).
- **Promo codes**, **Broadcast** (message all verified customers).

## Updating an existing install (shoes + covers)

1. Supabase -> SQL Editor -> New query -> paste `supabase-shoes.sql` -> Run. It adds the **Shoes (Oyoq kiyim)** category and 3 demo shoe products. (New installs already have this inside `supabase.sql`.)
2. Push the new code: `git add . && git commit -m "Shoes and covers" && git push`. Vercel redeploys by itself.
3. Admin panel -> Products -> **+ Add product**: choose Category **Shoes** and the sizes switch to **Shoes 39-46** automatically. Tick **Stock for each size** to set pieces per size.

## Pictures

- No drawings are used. A product without its own photo shows its **category cover** from the `covers/` folder.
- Cover files: `covers/<category>.jpg` (tile on the home page) and `covers/<category>-sq.jpg` (square, used for products). Categories: `tshirts`, `hoodies`, `shorts`, `tracksuits`, `accessories`, `shoes`.
- **Shoes has no cover yet.** Add `covers/shoes.jpg` and `covers/shoes-sq.jpg` (same style as the others) and push. Until then it shows a plain APEX tile.
- Real product photos: Admin -> Products -> open a product -> **+ Photo**. A product photo always replaces the cover.

## Make it yours

- `config.js`: brand, phone, address, opening hours, map coordinates, delivery fees, home banner. Push to GitHub to apply.
- Colours of the design: the `--accent` (orange `#FF5B1F`) and `--ink` values at the top of the `<style>` in `index.html` and `admin/index.html`.
- If you change a product's id/price/sizes in the built-in list of `index.html`, change `lib/catalog.js` too (`npm test` checks they match). Normally manage products only in the admin panel.
- Real photos: add them per product in the admin panel; until then the shop shows drawn product shapes.

## Troubleshooting

| Problem | Cause |
|---|---|
| "Demo rejim: server ulanmagan" | A variable is missing, or you did not Redeploy after adding it. Check Vercel -> Logs. |
| Bot ignores `/start` | Webhook not set (`curl https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo`) or secret differs from `WEBHOOK_SECRET`. |
| Order saved, nothing in the group | `STAFF_CHAT_ID` wrong or bot not admin. Run `/chatid` again. |
| "Faqat O'zbekiston raqamlari" | Number is not +998. Set `PHONE_PREFIX` to `any` for testing. |
| Admin says unauthorized | `ADMIN_PASSWORD` not set or not redeployed. |

## Notes

- Online payment for regional (BTS) orders is a **simulation**. For real Click / Payme you must integrate their server callbacks; set `DEMO_PAYMENTS=off` to hide the demo.
- Free OpenStreetMap map/search is for light traffic; use a paid tile provider for a busy store.
- Rotate the bot token (`/revoke` in BotFather) if it was ever posted anywhere, then update `BOT_TOKEN` and redo step 5.
