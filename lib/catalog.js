'use strict';
/* Server-side price list. The browser never sends prices: the server prices every order from this table.
   Keep ids, prices, sizes and colour lists in sync with the P array in index.html (scripts/test.js checks this). */

const CL = ['S', 'M', 'L', 'XL', 'XXL'];
const SH = ['39', '40', '41', '42', '43', '44', '45', '46'];

const CATALOG = {
  2: { price: 449000, sizes: CL, colors: ['#111111', '#6B7280', '#1F3A5F', '#D9D3D0'], uz: 'Peak Fleece hudi' },
  3: { price: 219000, sizes: CL, colors: ['#111111', '#1F3A5F', '#FF5B1F'], uz: 'Sprint 5" shorti' },
  9: { price: 329000, sizes: CL, colors: ['#111111', '#6B7280', '#1F3A5F'], uz: 'Summit jogger shim' },
  14: { price: 799000, sizes: SH, colors: ['#4A2F2B', '#111111', '#A7685C'], uz: 'Apex Cloud suv o\u2018tkazmas krossovka' },
  15: { price: 849000, sizes: SH, colors: ['#2B2845'], uz: 'Peak Hiker trekking krossovka' },
  16: { price: 729000, sizes: SH, colors: ['#8B6B82'], uz: 'Pace trail yugurish krossovka' },
  17: { price: 1290000, sizes: CL, colors: ['#8E2DC6'], uz: 'Apex Summit yengil kurtka' },
  18: { price: 689000, sizes: CL, colors: ['#111111'], uz: 'Apex Thermal zip kurtka' },
  19: { price: 899000, sizes: CL, colors: ['#111111'], uz: 'Apex Trail shamolga chidamli kurtka' },
  20: { price: 349000, sizes: null, colors: ['#111111'], uz: 'Apex Gear tote sumkasi' },
  21: { price: 129000, sizes: null, colors: ['#FFFFFF'], uz: 'Apex Trail panama' },
  22: { price: 249000, sizes: CL, colors: ['#111111'], uz: 'Apex Graphic futbolka' },
  30: { price: 549000, sizes: CL, colors: ['#F2C230'], uz: 'Apex Stadium futbol formasi' },
  31: { price: 599000, sizes: CL, colors: ['#111111'], uz: 'Apex Gold Static hudi' },
  32: { price: 629000, sizes: CL, colors: ['#4A2F2B'], uz: 'Apex Cocoa hudi' },
  33: { price: 169000, sizes: CL, colors: ['#FFFFFF'], uz: 'Apex Stride yugurish maykasi' },
  34: { price: 649000, sizes: CL, colors: ['#1F3A5F'], uz: 'Apex Solo zip hudi' },
  35: { price: 459000, sizes: CL, colors: ['#A9BC8E', '#111111'], uz: 'Apex Magna mashg\u2018ulot ustki kiyimi' },
  36: { price: 899000, sizes: SH, colors: ['#9AA5B1'], uz: 'Apex Retro Runner krossovka' },
  37: { price: 249000, sizes: SH, colors: ['#111111'], uz: 'Apex Victory shippak' },
  38: { price: 219000, sizes: null, colors: ['#F2C230'], uz: 'Apex Play poyabzal sumkasi' },
  39: { price: 129000, sizes: null, colors: ['#FFFFFF', '#111111'], uz: 'Apex Recharge butilka 24 oz' },
  40: { price: 399000, sizes: null, colors: ['#2F6FED'], uz: 'Apex Elite ryukzak' },
  41: { price: 259000, sizes: CL, colors: ['#111111'], uz: 'Apex Retro Graphic futbolka' },
};

const COLOR_NAMES = {
  '#FFFFFF': 'Oq',
  '#111111': 'Qora',
  '#FF5B1F': 'Apelsin',
  '#1F3A5F': 'To\u2018q ko\u2018k',
  '#6B7280': 'Kulrang',
  '#2F6FED': 'Ko\u2018k',
  '#3F5B3A': 'Zaytun',
  '#C8F03B': 'Laym',
  '#B3261E': 'Qizil',
  '#9AA5B1': 'Och kulrang',
  '#4A2F2B': 'Jigarrang',
  '#A7685C': 'Terrakota',
  '#2B2845': 'To\u2018q binafsha',
  '#8B6B82': 'Mov',
  '#8E2DC6': 'Binafsha',
  '#D9D3D0': 'Bej',
  '#F2C230': 'Sariq',
  '#A9BC8E': 'Och yashil',
};
const colorName = (hex) => COLOR_NAMES[hex] || hex;
/* Categories and sections saved in the admin panel (table shop_sections) -> lists of keys + names. Falls back to the built-in lists. */
function sectionsFrom(rows) {
  if (!Array.isArray(rows) || !rows.length) return { cats: CATS, subs: SUBS, names: {}, rows: [], db: Array.isArray(rows) };
  const names = {};
  rows.forEach((r) => { names[r.key] = { uz: r.uz, ru: r.ru }; });
  return { cats: rows.filter((r) => r.kind === 'cat').map((r) => r.key), subs: rows.filter((r) => r.kind === 'sub').map((r) => r.key), names, rows, db: true };
}
/* Custom size list typed in the admin panel ("XXL, 3XL" or one per line) -> array, or null when invalid. */
function parseSizes(v) {
  const raw = Array.isArray(v) ? v : String(v || '').split(/[,;\n]+/);
  const out = [];
  for (const x of raw) { const s = String(x).trim(); if (!s) continue; if (s.length > 8) return null; if (!out.includes(s)) out.push(s); }
  return out.length && out.length <= 14 ? out : null;
}
/* Colour palette saved in the admin panel (table shop_colors) -> { '#HEX': 'Name' }. Falls back to the built-in palette. */
const paletteFrom = (rows) => (Array.isArray(rows) && rows.length ? Object.fromEntries(rows.map((r) => [r.hex, r.name])) : COLOR_NAMES);

const CFG = require('../config.js');
const DELIVERY_FEE = CFG.fees.delivery;
const FREE_OVER = CFG.fees.freeOver;
const VILOYAT_FEE = CFG.fees.viloyat; // flat BTS Express fee to the regions (config.js)
const REGIONS = ['Qoraqalpog‘iston Respublikasi', 'Andijon viloyati', 'Buxoro viloyati', 'Farg‘ona viloyati', 'Jizzax viloyati', 'Xorazm viloyati', 'Namangan viloyati', 'Navoiy viloyati', 'Qashqadaryo viloyati', 'Samarqand viloyati', 'Sirdaryo viloyati', 'Surxondaryo viloyati', 'Toshkent viloyati'];
/* Delivery area: a box around Tashkent city. */
const ZONE = { latMin: 41.15, latMax: 41.47, lonMin: 69.08, lonMax: 69.45 };
const inZone = (lat, lon) => lat >= ZONE.latMin && lat <= ZONE.latMax && lon >= ZONE.lonMin && lon <= ZONE.lonMax;

const bad = () => Object.assign(new Error('bad_items'), { code: 'bad_items' });

/* Validate the cart and price it. Throws {code:'bad_items'} on anything unexpected. */
function priceOrder(rawItems, type, cat = CATALOG, promoPct = 0) {
  if (!Array.isArray(rawItems) || rawItems.length < 1 || rawItems.length > 30) throw bad();
  const lines = [];
  const used = {};
  let subtotal = 0;
  for (const it of rawItems) {
    if (!it || typeof it !== 'object') throw bad();
    const p = cat[it.id];
    if (!p || p.active === false) throw bad();
    const qty = Number(it.qty);
    if (!Number.isInteger(qty) || qty < 1 || qty > 20) throw bad();
    if (p.stock != null && qty > p.stock) throw Object.assign(new Error('out_of_stock'), { code: 'out_of_stock' });
    const ci = Number(it.color);
    if (!Number.isInteger(ci) || ci < 0 || ci >= p.colors.length) throw bad();
    let size = null;
    if (p.sizes) {
      if (!p.sizes.includes(it.size)) throw bad();
      size = it.size;
    }
    if (p.sizeStock) {
      const k = `${it.id}|${size}`;
      used[k] = (used[k] || 0) + qty;
      if (used[k] > (Number(p.sizeStock[size]) || 0)) throw Object.assign(new Error('out_of_stock'), { code: 'out_of_stock' });
    }
    lines.push({ id: Number(it.id), name: p.uz, size, color: p.colors[ci], ...(p.cn && p.cn[p.colors[ci]] ? { colorName: p.cn[p.colors[ci]] } : {}), qty, price: p.price });
    subtotal += p.price * qty;
  }
  const discount = Math.round((subtotal * promoPct) / 100);
  const fee = type === 'pickup' ? 0 : type === 'viloyat' ? VILOYAT_FEE : subtotal >= FREE_OVER ? 0 : DELIVERY_FEE;
  return { lines, subtotal, discount, fee, total: subtotal - discount + fee };
}

/* Products saved in the admin panel (Supabase table shop_products) -> same shape as CATALOG, with sale price applied. */
const effPrice = (r) => Math.round((r.price * (100 - (r.sale || 0))) / 100);
function toCatalog(rows, palette) {
  const o = {};
  for (const r of rows) o[r.id] = { price: effPrice(r), sizes: r.sizes, colors: r.colors, sizeStock: r.size_stock, uz: (r.name && r.name.uz) || '', stock: r.stock, active: r.active, cn: palette || null };
  return o;
}
const ARTS = ['tee', 'hoodie', 'shorts', 'tracksuit', 'trousers', 'duffel', 'tote', 'cap', 'bottle', 'sneaker', 'boot', 'shirt', 'knit', 'skirt', 'dress', 'coat', 'scarf'];
const MATS = ['dryfit', 'fleece', 'polyester', 'cotton', 'mesh', 'synthetic', 'canvas', 'leather', 'knit', 'wool', 'linen', 'viscose', 'suede', 'denim', 'silk', 'other'];
const CATS = ['tshirts', 'hoodies', 'jackets', 'shorts', 'tracksuits', 'accessories', 'shoes'];
const SUBS = ['training', 'running', 'lifestyle', 'bags', 'caps', 'bottles'];

module.exports = { VILOYAT_FEE, REGIONS, SH, SUBS, toCatalog, effPrice, ARTS, MATS, CATS, CL, COLOR_NAMES, paletteFrom, sectionsFrom, parseSizes, CATALOG, colorName, priceOrder, inZone, ZONE, DELIVERY_FEE, FREE_OVER };
