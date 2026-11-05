-- APEX SPORT: complete database setup. Run this ONCE in Supabase: SQL Editor -> New query -> paste everything -> Run.
-- Safe to run again (nothing is deleted or overwritten).

-- 1) Customers and orders ------------------------------------------------------------
create table if not exists customers (
  telegram_id  bigint primary key,
  phone        text not null,          -- digits only, e.g. 998901234567 (verified through Telegram)
  first_name   text,
  username     text,
  lang         text default 'uz',
  verified_at  timestamptz default now()
);

create table if not exists orders (
  id               bigserial primary key,
  telegram_id      bigint references customers(telegram_id),
  name             text,
  phone            text,
  type             text,               -- courier | pickup | viloyat
  address          text,
  lat              double precision,
  lon              double precision,
  pay              text,               -- cash | card | online
  items            jsonb,
  subtotal         integer,
  delivery_fee     integer,
  total            integer,
  status           text default 'new', -- new | accepted | on_way | delivered | cancelled
  handled_by       text,
  lang             text default 'uz',
  group_message_id bigint,
  created_at       timestamptz default now()
);
alter table orders add column if not exists promo text;
alter table orders add column if not exists discount int default 0;
alter table orders add column if not exists region text;
alter table orders add column if not exists district text;
alter table orders add column if not exists recipient_phone text;
alter table orders add column if not exists paid_at timestamptz;
alter table orders add column if not exists bts_track text;
alter table orders add column if not exists courier text;

-- 2) Products, promo codes -------------------------------------------------------------
create table if not exists shop_products (
  id int primary key, cat text, art text, mat text,
  price int, sale int default 0, stock int, active boolean default true,
  sizes jsonb, colors jsonb, name jsonb
);
alter table shop_products add column if not exists sub text;
alter table shop_products add column if not exists photos jsonb;
alter table shop_products add column if not exists size_stock jsonb;
alter table shop_products add column if not exists mat_text jsonb;
alter table shop_products add column if not exists is_new boolean default false;
create table if not exists promos (code text primary key, percent int, active boolean default true, used int default 0);

-- 3) Colours and categories managed from the admin panel ------------------------------
create table if not exists shop_colors (hex text primary key, name text not null, pos int default 0);
create table if not exists shop_sections (
  key text primary key,
  kind text not null check (kind in ('cat', 'sub')),
  uz text not null,
  ru text not null,
  pos int default 0
);

-- 4) Security: only the server (secret key) may read or write. No public policies on purpose.
alter table customers     enable row level security;
alter table orders        enable row level security;
alter table shop_products enable row level security;
alter table promos        enable row level security;
alter table shop_colors   enable row level security;
alter table shop_sections enable row level security;

-- 5) Safe stock: two orders at the same moment cannot buy the same last piece ----------
create or replace function take_stock(pid int, q int) returns boolean language plpgsql as $$
declare n int;
begin
  update shop_products set stock = case when stock is null then null else stock - q end
  where id = pid and (stock is null or stock >= q);
  get diagnostics n = row_count;
  return n > 0;
end $$;
create or replace function give_stock(pid int, q int) returns void language sql as $$
  update shop_products set stock = stock + q where id = pid and stock is not null;
$$;
create or replace function take_size_stock(pid int, sz text, q int) returns boolean language plpgsql as $$
declare cur int;
begin
  select coalesce((size_stock->>sz)::int, 0) into cur from shop_products where id = pid and size_stock is not null for update;
  if cur is null or cur < q then return false; end if;
  update shop_products set size_stock = jsonb_set(size_stock, array[sz], to_jsonb(cur - q)) where id = pid;
  update shop_products set stock = (select coalesce(sum(value::int), 0) from jsonb_each_text(size_stock)) where id = pid;
  return true;
end $$;
create or replace function give_size_stock(pid int, sz text, q int) returns void language plpgsql as $$
begin
  update shop_products set size_stock = jsonb_set(size_stock, array[sz], to_jsonb(coalesce((size_stock->>sz)::int, 0) + q)) where id = pid and size_stock is not null;
  update shop_products set stock = (select coalesce(sum(value::int), 0) from jsonb_each_text(size_stock)) where id = pid and size_stock is not null;
end $$;

-- 6) Public bucket for product photos (uploaded from the admin panel) ------------------
insert into storage.buckets (id, name, public) values ('products', 'products', true) on conflict (id) do nothing;

-- 7) Starting data: colours, categories, 16 demo products -------------------------------
insert into shop_colors (hex, name, pos) values
  ('#FFFFFF', 'Oq', 1),
  ('#111111', 'Qora', 2),
  ('#FF5B1F', 'Apelsin', 3),
  ('#1F3A5F', 'To‘q ko‘k', 4),
  ('#6B7280', 'Kulrang', 5),
  ('#2F6FED', 'Ko‘k', 6),
  ('#3F5B3A', 'Zaytun', 7),
  ('#C8F03B', 'Laym', 8),
  ('#B3261E', 'Qizil', 9),
  ('#9AA5B1', 'Och kulrang', 10)
on conflict (hex) do nothing;

insert into shop_sections (key, kind, uz, ru, pos) values
  ('tshirts', 'cat', 'Futbolkalar', 'Футболки', 1),
  ('hoodies', 'cat', 'Hudilar', 'Худи', 2),
  ('shorts', 'cat', 'Shortilar', 'Шорты', 3),
  ('tracksuits', 'cat', 'Sport kostyumlari', 'Спортивные костюмы', 4),
  ('accessories', 'cat', 'Aksessuarlar', 'Аксессуары', 5),
  ('shoes', 'cat', 'Oyoq kiyim', 'Обувь', 6),
  ('training', 'sub', 'Mashg‘ulot', 'Тренировка', 7),
  ('running', 'sub', 'Yugurish', 'Бег', 8),
  ('lifestyle', 'sub', 'Kundalik', 'Повседневное', 9),
  ('bags', 'sub', 'Sumkalar', 'Сумки', 10),
  ('caps', 'sub', 'Kepkalar', 'Кепки', 11),
  ('bottles', 'sub', 'Butilkalar', 'Бутылки', 12)
on conflict (key) do nothing;

insert into shop_products (id,cat,sub,art,mat,price,sale,stock,active,sizes,colors,name,is_new) values
(1,'tshirts','training','tee','dryfit',189000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#FFFFFF","#FF5B1F"]','{"uz":"Summit Dry-Fit futbolka","ru":"Футболка Summit Dry-Fit"}',true),
(2,'hoodies','lifestyle','hoodie','fleece',449000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#6B7280","#1F3A5F"]','{"uz":"Peak Fleece hudi","ru":"Худи Peak Fleece"}',true),
(3,'shorts','running','shorts','polyester',219000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#1F3A5F","#FF5B1F"]','{"uz":"Sprint 5\" shorti","ru":"Шорты Sprint 5\""}',true),
(4,'tracksuits','training','tracksuit','fleece',899000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#1F3A5F"]','{"uz":"Apex Pro sport kostyumi","ru":"Спортивный костюм Apex Pro"}',true),
(5,'tshirts','lifestyle','tee','cotton',159000,0,null,true,'["S","M","L","XL","XXL"]','["#FFFFFF","#111111","#6B7280"]','{"uz":"Core paxta futbolka","ru":"Хлопковая футболка Core"}',false),
(6,'tshirts','running','tee','dryfit',179000,15,null,true,'["S","M","L","XL","XXL"]','["#C8F03B","#111111","#2F6FED"]','{"uz":"Pace yugurish futbolkasi","ru":"Беговая футболка Pace"}',false),
(7,'hoodies','training','hoodie','fleece',479000,10,null,true,'["S","M","L","XL","XXL"]','["#3F5B3A","#111111","#9AA5B1"]','{"uz":"Trail zip hudi","ru":"Худи на молнии Trail"}',false),
(8,'shorts','training','shorts','polyester',239000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#6B7280","#B3261E"]','{"uz":"Tempo mashg‘ulot shortisi","ru":"Тренировочные шорты Tempo"}',false),
(9,'tracksuits','lifestyle','trousers','fleece',329000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#6B7280","#1F3A5F"]','{"uz":"Summit jogger shim","ru":"Джоггеры Summit"}',false),
(10,'tracksuits','lifestyle','tracksuit','polyester',649000,0,null,true,'["S","M","L","XL","XXL"]','["#6B7280","#111111","#2F6FED"]','{"uz":"Apex Core sport kostyumi","ru":"Спортивный костюм Apex Core"}',false),
(11,'accessories','bags','duffel','polyester',299000,0,null,true,null,'["#111111","#FF5B1F"]','{"uz":"Apex sport sumkasi","ru":"Спортивная сумка Apex"}',false),
(12,'accessories','caps','cap','polyester',99000,0,null,true,null,'["#111111","#FFFFFF","#FF5B1F"]','{"uz":"Apex Run kepka","ru":"Кепка Apex Run"}',false),
(13,'accessories','bottles','bottle','synthetic',89000,0,null,true,null,'["#111111","#FF5B1F"]','{"uz":"Apex shaker butilka","ru":"Шейкер Apex"}',false),
(14,'shoes','running','sneaker','mesh',649000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#111111","#FFFFFF","#FF5B1F"]','{"uz":"Apex Runner krossovka","ru":"Кроссовки Apex Runner"}',true),
(15,'shoes','training','sneaker','synthetic',589000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#111111","#6B7280"]','{"uz":"Peak Trainer krossovka","ru":"Кроссовки Peak Trainer"}',false),
(16,'shoes','lifestyle','boot','leather',729000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#3F5B3A","#111111"]','{"uz":"Summit trail botinka","ru":"Трекинговые ботинки Summit"}',false)
on conflict (id) do nothing;
