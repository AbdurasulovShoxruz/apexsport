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
alter table shop_products add column if not exists descr jsonb;
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
  ('#8E2DC6', 'Binafsha', 15),
  ('#D9D3D0', 'Bej', 16),
  ('#F2C230', 'Sariq', 17),
  ('#A9BC8E', 'Och yashil', 18)
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
(2,'hoodies','lifestyle','hoodie','fleece',449000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#6B7280","#1F3A5F"]','{"uz":"Peak Fleece hudi","ru":"Худи Peak Fleece"}',true,null),
(3,'shorts','running','shorts','polyester',219000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#1F3A5F","#FF5B1F"]','{"uz":"Sprint 5\" shorti","ru":"Шорты Sprint 5\""}',true,null),
(9,'tracksuits','lifestyle','trousers','fleece',329000,0,null,true,'["S","M","L","XL","XXL"]','["#111111","#6B7280","#1F3A5F"]','{"uz":"Summit jogger shim","ru":"Джоггеры Summit"}',false,null),
(14,'shoes','running','sneaker','mesh',799000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#4A2F2B","#111111","#A7685C"]','{"uz":"Apex Cloud suv o‘tkazmas krossovka","ru":"Водонепроницаемые кроссовки Apex Cloud"}',true,'[{"u":"/photos/cloud-brown-1.jpg","c":"#4A2F2B"},{"u":"/photos/cloud-brown-2.jpg","c":"#4A2F2B"},{"u":"/photos/cloud-brown-3.jpg","c":"#4A2F2B"},{"u":"/photos/cloud-black-1.jpg","c":"#111111"},{"u":"/photos/cloud-black-2.jpg","c":"#111111"},{"u":"/photos/cloud-black-3.jpg","c":"#111111"},{"u":"/photos/cloud-rose-1.jpg","c":"#A7685C"},{"u":"/photos/cloud-rose-2.jpg","c":"#A7685C"},{"u":"/photos/cloud-rose-3.jpg","c":"#A7685C"}]'),
(15,'shoes','lifestyle','sneaker','synthetic',849000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#2B2845"]','{"uz":"Peak Hiker trekking krossovka","ru":"Трекинговые кроссовки Peak Hiker"}',true,'[{"u":"/photos/hiker-1.jpg","c":"#2B2845"},{"u":"/photos/hiker-2.jpg","c":"#2B2845"},{"u":"/photos/hiker-3.jpg","c":"#2B2845"}]'),
(16,'shoes','running','sneaker','mesh',729000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#8B6B82"]','{"uz":"Pace trail yugurish krossovka","ru":"Трейловые кроссовки Pace"}',false,'[{"u":"/photos/trail-1.jpg","c":"#8B6B82"},{"u":"/photos/trail-2.jpg","c":"#8B6B82"},{"u":"/photos/trail-3.jpg","c":"#8B6B82"}]'),
(17,'jackets','training','hoodie','polyester',1290000,0,null,true,'["S","M","L","XL","XXL"]','["#8E2DC6"]','{"uz":"Apex Summit yengil kurtka","ru":"Куртка-ветровка Apex Summit"}',true,'[{"u":"/photos/shell-1.jpg","c":"#8E2DC6"},{"u":"/photos/shell-2.jpg","c":"#8E2DC6"},{"u":"/photos/shell-3.jpg","c":"#8E2DC6"}]'),
(18,'jackets','running','hoodie','fleece',689000,0,null,true,'["S","M","L","XL","XXL"]','["#111111"]','{"uz":"Apex Thermal zip kurtka","ru":"Термокуртка на молнии Apex"}',true,'[{"u":"/photos/zip-1.jpg","c":"#111111"},{"u":"/photos/zip-2.jpg","c":"#111111"},{"u":"/photos/zip-3.jpg","c":"#111111"}]')
on conflict (id) do nothing;

-- Photos for products that already exist (2 hoodie, 3 shorts, 9 jogger pants). Stock and discount you set are kept.
update shop_products set colors = '["#111111","#6B7280","#1F3A5F","#D9D3D0"]', photos = '[{"u":"/photos/hoodie-2.jpg","c":"#D9D3D0"},{"u":"/photos/hoodie-3.jpg","c":"#D9D3D0"},{"u":"/photos/hoodie-1.jpg","c":"#D9D3D0"}]' where id = 2;
update shop_products set photos = '[{"u":"/photos/shorts-1.jpg","c":"#111111"},{"u":"/photos/shorts-2.jpg","c":"#111111"},{"u":"/photos/shorts-3.jpg","c":"#111111"}]' where id = 3;
update shop_products set photos = '[{"u":"/photos/fleece-pants-4.jpg","c":"#111111"},{"u":"/photos/fleece-pants-3.jpg","c":"#111111"},{"u":"/photos/fleece-pants-2.jpg","c":"#111111"},{"u":"/photos/fleece-pants-1.jpg","c":"#111111"},{"u":"/photos/fleece-pants-5.jpg","c":"#111111"}]' where id = 9;

-- New products 19-21: windbreaker, tote bag, bucket hat
insert into shop_products (id,cat,sub,art,mat,price,sale,stock,active,sizes,colors,name,is_new,photos) values
(19,'jackets','running','coat','polyester',899000,0,null,true,'["S","M","L","XL","XXL"]','["#111111"]','{"uz":"Apex Trail shamolga chidamli kurtka","ru":"Ветровка Apex Trail"}',true,'[{"u":"/photos/windbreaker-1.jpg","c":"#111111"},{"u":"/photos/windbreaker-2.jpg","c":"#111111"},{"u":"/photos/windbreaker-3.jpg","c":"#111111"},{"u":"/photos/windbreaker-5.jpg","c":"#111111"}]'),
(20,'accessories','bags','tote','polyester',349000,0,null,true,null,'["#111111"]','{"uz":"Apex Gear tote sumkasi","ru":"Сумка-тоут Apex Gear"}',true,'[{"u":"/photos/tote-2.jpg","c":"#111111"},{"u":"/photos/tote-3.jpg","c":"#111111"},{"u":"/photos/tote-1.jpg","c":"#111111"}]'),
(21,'accessories','caps','cap','mesh',129000,0,null,true,null,'["#FFFFFF"]','{"uz":"Apex Trail panama","ru":"Панама Apex Trail"}',true,'[{"u":"/photos/bucket-hat-2.jpg","c":"#FFFFFF"},{"u":"/photos/bucket-hat-1.jpg","c":"#FFFFFF"}]')
on conflict (id) do update set
  cat = excluded.cat, sub = excluded.sub, art = excluded.art, mat = excluded.mat, price = excluded.price,
  sizes = excluded.sizes, colors = excluded.colors, name = excluded.name, is_new = excluded.is_new, photos = excluded.photos;

-- Descriptions and product 22
update shop_products set descr = '{"uz":"Yomg‘ir va ko‘lmakda ham oyoqni quruq saqlaydigan suv o‘tkazmas krossovka. Yengil va yumshoq, kundalik yurish va shahar sayrlari uchun; uch xil rangda.","ru":"Водонепроницаемые кроссовки, которые держат ноги сухими в дождь и по лужам. Лёгкие и мягкие, для ежедневной носки и прогулок по городу; три цвета.","en":"Waterproof sneakers that keep your feet dry in rain and puddles. Light and soft for everyday wear and city walks, in three colours."}' where id = 14;
update shop_products set descr = '{"uz":"Notekis yo‘llar uchun trekking krossovkasi: ishonchli ilashish va barqaror tayanch. Tog‘ yo‘llari va uzoq yurishlar uchun.","ru":"Трекинговые кроссовки для неровных троп: надёжное сцепление и устойчивость. Для горных маршрутов и долгих прогулок.","en":"Trekking sneakers for uneven trails, with dependable grip and a stable base. Made for hill paths and long walks."}' where id = 15;
update shop_products set descr = '{"uz":"Trail yugurish uchun yumshoq amortizatsiyali krossovka. Tuproq va aralash yo‘llarda ilashishi yaxshi, mashg‘ulot kunlari uchun qulay.","ru":"Кроссовки для трейлраннинга с мягкой амортизацией. Хорошее сцепление на грунте и смешанных покрытиях, удобны для тренировок.","en":"Trail running sneakers with soft cushioning. Good grip on dirt and mixed ground, comfortable for training days."}' where id = 16;
update shop_products set descr = '{"uz":"Shamoldan himoya qiluvchi yengil kurtka. Sumkada kam joy egallaydi, yugurish, yurish va sayohatlar uchun qulay.","ru":"Лёгкая куртка-ветровка, защищает от ветра. Занимает мало места в сумке, удобна для бега, прогулок и поездок.","en":"A lightweight shell jacket that blocks the wind. Takes little space in your bag, handy for runs, walks and trips."}' where id = 17;
update shop_products set descr = '{"uz":"Sovuq kunlar uchun issiq zip kurtka. Yumshoq to‘qima, to‘liq zamok va erkin kesim: mashg‘ulotdan oldin va keyin kiyish uchun.","ru":"Тёплая куртка на молнии для прохладных дней. Мягкая ткань, полная молния и свободный крой: надевать до и после тренировки.","en":"A warm zip jacket for cool days. Soft fabric, full zip and a relaxed cut, easy to throw on before and after training."}' where id = 18;
update shop_products set descr = '{"uz":"Kapyushonli yengil shamolga chidamli kurtka. Zamokli cho‘ntak va yengil mato, trail yugurish va ertalabki mashqlar uchun.","ru":"Лёгкая ветровка с капюшоном. Карман на молнии и тонкая ткань, для трейлраннинга и утренних тренировок.","en":"A light hooded windbreaker with a zip pocket and thin fabric, made for trail runs and morning workouts."}' where id = 19;

-- New product 22: Apex Graphic Tee
insert into shop_products (id,cat,sub,art,mat,price,sale,stock,active,sizes,colors,name,is_new,photos,descr) values
(22,'tshirts','lifestyle','tee','cotton',249000,0,null,true,'["S","M","L","XL","XXL"]','["#111111"]','{"uz":"Apex Graphic futbolka","ru":"Футболка Apex Graphic"}',true,'[{"u":"https://static.nike.com/a/images/24c0ed05-6a29-46b8-b2f0-d0bf0c8ae90f/sportswear-mens-t-shirt-dWXxKP.png","c":"#111111"},{"u":"https://static.nike.com/a/images/a6355a88-166c-408e-91e5-e056b19eebac/sportswear-mens-t-shirt-dWXxKP.png","c":"#111111"},{"u":"https://static.nike.com/a/images/139dd2f3-e2d4-420d-9428-0526fb3d110c/sportswear-mens-t-shirt-dWXxKP.png","c":"#111111"},{"u":"https://static.nike.com/a/images/b04e0355-7b99-483a-a23b-f5b3074154dc/sportswear-mens-t-shirt-dWXxKP.png","c":"#111111"}]','{"uz":"Erkin kesimli paxta futbolka: yumshoq mato, ribli yoqa va old tomonda yirik bosma grafika. Kundalik kiyish uchun.","ru":"Футболка свободного кроя из мягкого хлопка: резинка на вороте и крупный принт на груди. Для повседневной носки.","en":"A relaxed-fit cotton tee with a ribbed collar and a large printed graphic on the front. Made for everyday wear."}')
on conflict (id) do update set cat = excluded.cat, sub = excluded.sub, art = excluded.art, mat = excluded.mat, price = excluded.price,
  sizes = excluded.sizes, colors = excluded.colors, name = excluded.name, is_new = excluded.is_new, photos = excluded.photos, descr = excluded.descr;

-- 12 photo products (30-41)
insert into shop_products (id,cat,sub,art,mat,price,sale,stock,active,sizes,colors,name,is_new,photos,descr) values
(30,'tshirts','training','tee','dryfit',549000,0,null,true,'["S","M","L","XL","XXL"]','["#F2C230"]','{"uz":"Apex Stadium futbol formasi","ru":"Футбольная джерси Apex Stadium"}',true,'[{"u":"/photos/jersey-1.jpg","c":"#F2C230"},{"u":"/photos/jersey-2.jpg","c":"#F2C230"},{"u":"/photos/jersey-3.jpg","c":"#F2C230"},{"u":"/photos/jersey-4.jpg","c":"#F2C230"}]','{"uz":"Yengil, nafas oladigan futbol formasi: terni tez chiqaradigan mato va qulay kesim. O‘yin va mashg‘ulot uchun.","ru":"Лёгкая дышащая футбольная джерси из влагоотводящей ткани. Для игры и тренировок.","en":"A light, breathable football jersey in sweat-wicking fabric. Made for matches and training."}'),
(31,'hoodies','lifestyle','hoodie','fleece',599000,0,null,true,'["S","M","L","XL","XXL"]','["#111111"]','{"uz":"Apex Gold Static hudi","ru":"Худи Apex Gold Static"}',true,'[{"u":"/photos/lakers-hoodie-1.jpg","c":"#111111"},{"u":"/photos/lakers-hoodie-4.jpg","c":"#111111"},{"u":"/photos/lakers-hoodie-3.jpg","c":"#111111"},{"u":"/photos/lakers-hoodie-2.jpg","c":"#111111"}]','{"uz":"Qora hudi, oltin rangli bo‘yoq effekti bilan. Yumshoq, qalin mato, kundalik kiyish uchun.","ru":"Чёрное худи с золотистым градиентным принтом. Мягкая плотная ткань для повседневной носки.","en":"A black hoodie with a golden spray effect. Soft, thick fabric for everyday wear."}'),
(32,'hoodies','lifestyle','hoodie','fleece',629000,0,null,true,'["S","M","L","XL","XXL"]','["#4A2F2B"]','{"uz":"Apex Cocoa hudi","ru":"Худи Apex Cocoa"}',true,'[{"u":"/photos/jordan-hoodie-1.jpg","c":"#4A2F2B"},{"u":"/photos/jordan-hoodie-3.jpg","c":"#4A2F2B"},{"u":"/photos/jordan-hoodie-2.jpg","c":"#4A2F2B"}]','{"uz":"Jigarrang rangli erkin kesimli hudi, katta kapyushon va old cho‘ntak bilan.","ru":"Коричневое худи свободного кроя с большим капюшоном и карманом-кенгуру.","en":"A brown relaxed-fit hoodie with a roomy hood and a front pocket."}'),
(33,'tshirts','running','tee','dryfit',169000,0,null,true,'["S","M","L","XL","XXL"]','["#FFFFFF"]','{"uz":"Apex Stride yugurish maykasi","ru":"Беговая майка Apex Stride"}',false,'[{"u":"/photos/tank-1.jpg","c":"#FFFFFF"},{"u":"/photos/tank-2.jpg","c":"#FFFFFF"},{"u":"/photos/tank-3.jpg","c":"#FFFFFF"}]','{"uz":"Yengil mayka: issiq kunlarda yugurish va mashg‘ulot uchun. Erkin harakat uchun keng kesim.","ru":"Лёгкая майка для бега и тренировок в жару. Свободный крой не стесняет движений.","en":"A light tank for runs and training in the heat. A loose cut that lets you move freely."}'),
(34,'hoodies','training','hoodie','fleece',649000,0,null,true,'["S","M","L","XL","XXL"]','["#1F3A5F"]','{"uz":"Apex Solo zip hudi","ru":"Худи на молнии Apex Solo"}',true,'[{"u":"/photos/zip-hoodie-1.jpg","c":"#1F3A5F"},{"u":"/photos/zip-hoodie-3.jpg","c":"#1F3A5F"},{"u":"/photos/zip-hoodie-4.jpg","c":"#1F3A5F"},{"u":"/photos/zip-hoodie-2.jpg","c":"#1F3A5F"}]','{"uz":"To‘q ko‘k zip hudi: yumshoq mato, to‘liq zamok va erkin kesim. Shim bilan komplekt qilib kiyish mumkin.","ru":"Тёмно-синее худи на молнии: мягкая ткань, полная молния и свободный крой. Хорошо смотрится с брюками в комплект.","en":"A navy zip hoodie with soft fabric, a full zip and a relaxed cut. Pairs well with matching pants."}'),
(35,'tshirts','training','tee','dryfit',459000,0,null,true,'["S","M","L","XL","XXL"]','["#A9BC8E","#111111"]','{"uz":"Apex Magna mashg‘ulot ustki kiyimi","ru":"Тренировочный лонгслив Apex Magna"}',true,'[{"u":"/photos/magna-top-1.jpg","c":"#A9BC8E"},{"u":"/photos/magna-top-2.jpg","c":"#A9BC8E"},{"u":"/photos/magna-top-3.jpg","c":"#A9BC8E"},{"u":"/photos/magna-top-4.jpg","c":"#111111"},{"u":"/photos/magna-top-5.jpg","c":"#111111"},{"u":"/photos/magna-top-6.jpg","c":"#111111"},{"u":"/photos/magna-top-7.jpg","c":"#111111"}]','{"uz":"Uzun yengli mashg‘ulot kiyimi, kontrastli panellar va yirik logotip bilan. Ikki rangda.","ru":"Тренировочный лонгслив с контрастными вставками и крупным логотипом. Два цвета.","en":"A long-sleeve training top with contrast panels and a large logo. Two colours."}'),
(36,'shoes','running','sneaker','mesh',899000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#9AA5B1"]','{"uz":"Apex Retro Runner krossovka","ru":"Кроссовки Apex Retro Runner"}',true,'[{"u":"/photos/p6000-1.jpg","c":"#9AA5B1"},{"u":"/photos/p6000-4.jpg","c":"#9AA5B1"},{"u":"/photos/p6000-2.jpg","c":"#9AA5B1"},{"u":"/photos/p6000-3.jpg","c":"#9AA5B1"}]','{"uz":"Retro uslubdagi yugurish krossovkasi: kumush rang, yumshoq poyabzal va kundalik kiyish uchun qulay.","ru":"Кроссовки в ретро-стиле для бега, серебристый цвет, мягкая посадка для ежедневной носки.","en":"Retro-style running sneakers in silver, with a soft fit that works for everyday wear."}'),
(37,'shoes','lifestyle','sneaker','synthetic',249000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#111111"]','{"uz":"Apex Victory shippak","ru":"Шлёпанцы Apex Victory"}',false,'[{"u":"/photos/slide-1.jpg","c":"#111111"},{"u":"/photos/slide-2.jpg","c":"#111111"},{"u":"/photos/slide-3.jpg","c":"#111111"},{"u":"/photos/slide-4.jpg","c":"#111111"}]','{"uz":"Dush, basseyn va uyda kiyish uchun qora shippak. Yengil va yumshoq.","ru":"Чёрные шлёпанцы для душа, бассейна и дома. Лёгкие и мягкие.","en":"Black slides for the shower, the pool and home. Light and soft."}'),
(38,'accessories','bags','duffel','polyester',219000,0,null,true,null,'["#F2C230"]','{"uz":"Apex Play poyabzal sumkasi","ru":"Сумка для обуви Apex Play"}',true,'[{"u":"/photos/lego-bag-1.jpg","c":"#F2C230"},{"u":"/photos/lego-bag-2.jpg","c":"#F2C230"},{"u":"/photos/lego-bag-3.jpg","c":"#F2C230"},{"u":"/photos/lego-bag-4.jpg","c":"#F2C230"}]','{"uz":"Poyabzal uchun ixcham sumka: ikki tutqich va ichki bo‘linma. Yorqin naqsh bilan.","ru":"Компактная сумка для обуви с двумя ручками и внутренним отсеком. Яркий принт.","en":"A compact shoe bag with two handles and an inner compartment. Bright pattern."}'),
(39,'accessories','bottles','bottle','synthetic',129000,0,null,true,null,'["#FFFFFF","#111111"]','{"uz":"Apex Recharge butilka 24 oz","ru":"Бутылка Apex Recharge 24 oz"}',true,'[{"u":"/photos/bottle-1.jpg","c":"#FFFFFF"},{"u":"/photos/bottle-2.jpg","c":"#FFFFFF"},{"u":"/photos/bottle-3.jpg","c":"#111111"},{"u":"/photos/bottle-4.jpg","c":"#111111"}]','{"uz":"Mashg‘ulot uchun 24 oz (taxminan 700 ml) butilka, qopqog‘ida tutqich bilan. Ikki rangda.","ru":"Бутылка для тренировок на 24 oz (около 700 мл) с ручкой на крышке. Два цвета.","en":"A 24 oz (about 700 ml) training bottle with a carry loop on the lid. Two colours."}'),
(40,'accessories','bags','duffel','polyester',399000,0,null,true,null,'["#2F6FED"]','{"uz":"Apex Elite ryukzak","ru":"Рюкзак Apex Elite"}',true,'[{"u":"/photos/backpack-2.jpg","c":"#2F6FED"},{"u":"/photos/backpack-1.jpg","c":"#2F6FED"},{"u":"/photos/backpack-3.jpg","c":"#2F6FED"},{"u":"/photos/backpack-4.jpg","c":"#2F6FED"}]','{"uz":"Katta sport ryukzagi: ko‘p bo‘linmali, pastki qismi poyabzal uchun. Mashg‘ulot va o‘qish uchun.","ru":"Вместительный спортивный рюкзак с несколькими отделениями и нижним отсеком под обувь. Для тренировок и учёбы.","en":"A roomy sports backpack with several compartments and a base pocket for shoes. For training and school."}'),
(41,'tshirts','lifestyle','tee','cotton',259000,0,null,true,'["S","M","L","XL","XXL"]','["#111111"]','{"uz":"Apex Retro Graphic futbolka","ru":"Футболка Apex Retro Graphic"}',true,'[{"u":"/photos/tee-1.jpg","c":"#111111"},{"u":"/photos/tee-3.jpg","c":"#111111"},{"u":"/photos/tee-2.jpg","c":"#111111"}]','{"uz":"Qora paxta futbolka, old tomonda yorqin retro grafika. Erkin kesim, kundalik kiyish uchun.","ru":"Чёрная хлопковая футболка с яркой ретро-графикой на груди. Свободный крой для повседневной носки.","en":"A black cotton tee with a bright retro graphic on the front. Relaxed fit for everyday wear."}')
on conflict (id) do update set cat = excluded.cat, sub = excluded.sub, art = excluded.art, mat = excluded.mat, price = excluded.price,
  sizes = excluded.sizes, colors = excluded.colors, name = excluded.name, is_new = excluded.is_new, photos = excluded.photos, descr = excluded.descr;
