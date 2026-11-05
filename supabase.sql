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

-- 7) Starting data: colours, categories, 18 demo products -------------------------------
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
  ('#9AA5B1', 'Och kulrang', 10),
  ('#4A2F2B', 'Jigarrang', 11),
  ('#A7685C', 'Terrakota', 12),
  ('#2B2845', 'To‘q binafsha', 13),
  ('#8B6B82', 'Mov', 14),
  ('#8E2DC6', 'Binafsha', 15)
on conflict (hex) do nothing;

insert into shop_sections (key, kind, uz, ru, pos) values
  ('tshirts', 'cat', 'Futbolkalar', 'Футболки', 1),
  ('hoodies', 'cat', 'Hudilar', 'Худи', 2),
  ('jackets', 'cat', 'Kurtkalar', 'Куртки', 3),
  ('shorts', 'cat', 'Shortilar', 'Шорты', 4),
  ('tracksuits', 'cat', 'Sport kostyumlari', 'Спортивные костюмы', 5),
  ('accessories', 'cat', 'Aksessuarlar', 'Аксессуары', 6),
  ('shoes', 'cat', 'Oyoq kiyim', 'Обувь', 7),
  ('training', 'sub', 'Mashg‘ulot', 'Тренировка', 8),
  ('running', 'sub', 'Yugurish', 'Бег', 9),
  ('lifestyle', 'sub', 'Kundalik', 'Повседневное', 10),
  ('bags', 'sub', 'Sumkalar', 'Сумки', 11),
  ('caps', 'sub', 'Kepkalar', 'Кепки', 12),
  ('bottles', 'sub', 'Butilkalar', 'Бутылки', 13)
on conflict (key) do nothing;

insert into shop_products (id,cat,sub,art,mat,price,sale,stock,active,sizes,colors,name,is_new,photos) values
(1,'tshirts','training','tee','dryfit',189000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#FFFFFF","#FF5B1F"]','{"uz":"Summit Dry-Fit futbolka","ru":"Футболка Summit Dry-Fit"}',true,null),
(2,'hoodies','lifestyle','hoodie','fleece',449000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#6B7280","#1F3A5F"]','{"uz":"Peak Fleece hudi","ru":"Худи Peak Fleece"}',true,null),
(3,'shorts','running','shorts','polyester',219000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#1F3A5F","#FF5B1F"]','{"uz":"Sprint 5\" shorti","ru":"Шорты Sprint 5\""}',true,null),
(4,'tracksuits','training','tracksuit','fleece',899000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#1F3A5F"]','{"uz":"Apex Pro sport kostyumi","ru":"Спортивный костюм Apex Pro"}',true,null),
(5,'tshirts','lifestyle','tee','cotton',159000,0,null,true,'["S","M","L","XL","XXL"]','["#FFFFFF","#111111","#6B7280"]','{"uz":"Core paxta futbolka","ru":"Хлопковая футболка Core"}',false,null),
(6,'tshirts','running','tee','dryfit',179000,15,null,true,'["S","M","L","XL","XXL"]','["#C8F03B","#111111","#2F6FED"]','{"uz":"Pace yugurish futbolkasi","ru":"Беговая футболка Pace"}',false,null),
(7,'hoodies','training','hoodie','fleece',479000,10,null,true,'["S","M","L","XL","XXL"]','["#3F5B3A","#111111","#9AA5B1"]','{"uz":"Trail zip hudi","ru":"Худи на молнии Trail"}',false,null),
(8,'shorts','training','shorts','polyester',239000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#6B7280","#B3261E"]','{"uz":"Tempo mashg‘ulot shortisi","ru":"Тренировочные шорты Tempo"}',false,null),
(9,'tracksuits','lifestyle','trousers','fleece',329000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#6B7280","#1F3A5F"]','{"uz":"Summit jogger shim","ru":"Джоггеры Summit"}',false,null),
(10,'tracksuits','lifestyle','tracksuit','polyester',649000,0,null,true,'["S","M","L","XL","XXL"]','["#6B7280","#111111","#2F6FED"]','{"uz":"Apex Core sport kostyumi","ru":"Спортивный костюм Apex Core"}',false,null),
(11,'accessories','bags','duffel','polyester',299000,0,null,true,null,'["#111111","#FF5B1F"]','{"uz":"Apex sport sumkasi","ru":"Спортивная сумка Apex"}',false,null),
(12,'accessories','caps','cap','polyester',99000,0,null,true,null,'["#111111","#FFFFFF","#FF5B1F"]','{"uz":"Apex Run kepka","ru":"Кепка Apex Run"}',false,null),
(13,'accessories','bottles','bottle','synthetic',89000,0,null,true,null,'["#111111","#FF5B1F"]','{"uz":"Apex shaker butilka","ru":"Шейкер Apex"}',false,null),
(14,'shoes','running','sneaker','mesh',799000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#4A2F2B","#111111","#A7685C"]','{"uz":"Apex Cloud suv o‘tkazmas krossovka","ru":"Водонепроницаемые кроссовки Apex Cloud"}',true,'[{"u":"/photos/cloud-brown-1.jpg","c":"#4A2F2B"},{"u":"/photos/cloud-brown-2.jpg","c":"#4A2F2B"},{"u":"/photos/cloud-brown-3.jpg","c":"#4A2F2B"},{"u":"/photos/cloud-black-1.jpg","c":"#111111"},{"u":"/photos/cloud-black-2.jpg","c":"#111111"},{"u":"/photos/cloud-black-3.jpg","c":"#111111"},{"u":"/photos/cloud-rose-1.jpg","c":"#A7685C"},{"u":"/photos/cloud-rose-2.jpg","c":"#A7685C"},{"u":"/photos/cloud-rose-3.jpg","c":"#A7685C"}]'),
(15,'shoes','lifestyle','sneaker','synthetic',849000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#2B2845"]','{"uz":"Peak Hiker trekking krossovka","ru":"Трекинговые кроссовки Peak Hiker"}',true,'[{"u":"/photos/hiker-1.jpg","c":"#2B2845"},{"u":"/photos/hiker-2.jpg","c":"#2B2845"},{"u":"/photos/hiker-3.jpg","c":"#2B2845"}]'),
(16,'shoes','running','sneaker','mesh',729000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#8B6B82"]','{"uz":"Pace trail yugurish krossovka","ru":"Трейловые кроссовки Pace"}',false,'[{"u":"/photos/trail-1.jpg","c":"#8B6B82"},{"u":"/photos/trail-2.jpg","c":"#8B6B82"},{"u":"/photos/trail-3.jpg","c":"#8B6B82"}]'),
(17,'jackets','training','hoodie','polyester',1290000,0,null,true,'["S","M","L","XL","XXL"]','["#8E2DC6"]','{"uz":"Apex Summit yengil kurtka","ru":"Куртка-ветровка Apex Summit"}',true,'[{"u":"/photos/shell-1.jpg","c":"#8E2DC6"},{"u":"/photos/shell-2.jpg","c":"#8E2DC6"},{"u":"/photos/shell-3.jpg","c":"#8E2DC6"}]'),
(18,'jackets','running','hoodie','fleece',689000,0,null,true,'["S","M","L","XL","XXL"]','["#111111"]','{"uz":"Apex Thermal zip kurtka","ru":"Термокуртка на молнии Apex"}',true,'[{"u":"/photos/zip-1.jpg","c":"#111111"},{"u":"/photos/zip-2.jpg","c":"#111111"},{"u":"/photos/zip-3.jpg","c":"#111111"}]')
on conflict (id) do nothing;
