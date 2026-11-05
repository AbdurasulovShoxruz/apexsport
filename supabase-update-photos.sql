-- APEX SPORT update for an EXISTING database: Shoes + Jackets categories and the photo products.
-- Run once in Supabase: SQL Editor -> New query -> paste everything -> Run. Safe to run again.
-- (New installs do not need this file: supabase.sql already contains everything.)

-- 1) New colours used by the photo products
insert into shop_colors (hex, name, pos) values
  ('#4A2F2B', 'Jigarrang', 11),
  ('#A7685C', 'Terrakota', 12),
  ('#2B2845', 'To‘q binafsha', 13),
  ('#8B6B82', 'Mov', 14),
  ('#8E2DC6', 'Binafsha', 15)
on conflict (hex) do nothing;

-- 2) Categories and their order in the shop: T-shirts, Hoodies, Jackets, Shorts, Tracksuits, Accessories, Shoes
insert into shop_sections (key, kind, uz, ru, pos) values
  ('tshirts', 'cat', 'Futbolkalar', 'Футболки', 1),
  ('hoodies', 'cat', 'Hudilar', 'Худи', 2),
  ('jackets', 'cat', 'Kurtkalar', 'Куртки', 3),
  ('shorts', 'cat', 'Shortilar', 'Шорты', 4),
  ('tracksuits', 'cat', 'Sport kostyumlari', 'Спортивные костюмы', 5),
  ('accessories', 'cat', 'Aksessuarlar', 'Аксессуары', 6),
  ('shoes', 'cat', 'Oyoq kiyim', 'Обувь', 7)
on conflict (key) do update set uz = excluded.uz, ru = excluded.ru, pos = excluded.pos;

-- 3) Products 14-18 with photos (14-16 replace the earlier demo shoes; stock and discount you set are kept)
insert into shop_products (id,cat,sub,art,mat,price,sale,stock,active,sizes,colors,name,is_new,photos) values
(14,'shoes','running','sneaker','mesh',799000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#4A2F2B","#111111","#A7685C"]','{"uz":"Apex Cloud suv o‘tkazmas krossovka","ru":"Водонепроницаемые кроссовки Apex Cloud"}',true,'[{"u":"/photos/cloud-brown-1.jpg","c":"#4A2F2B"},{"u":"/photos/cloud-brown-2.jpg","c":"#4A2F2B"},{"u":"/photos/cloud-brown-3.jpg","c":"#4A2F2B"},{"u":"/photos/cloud-black-1.jpg","c":"#111111"},{"u":"/photos/cloud-black-2.jpg","c":"#111111"},{"u":"/photos/cloud-black-3.jpg","c":"#111111"},{"u":"/photos/cloud-rose-1.jpg","c":"#A7685C"},{"u":"/photos/cloud-rose-2.jpg","c":"#A7685C"},{"u":"/photos/cloud-rose-3.jpg","c":"#A7685C"}]'),
(15,'shoes','lifestyle','sneaker','synthetic',849000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#2B2845"]','{"uz":"Peak Hiker trekking krossovka","ru":"Трекинговые кроссовки Peak Hiker"}',true,'[{"u":"/photos/hiker-1.jpg","c":"#2B2845"},{"u":"/photos/hiker-2.jpg","c":"#2B2845"},{"u":"/photos/hiker-3.jpg","c":"#2B2845"}]'),
(16,'shoes','running','sneaker','mesh',729000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#8B6B82"]','{"uz":"Pace trail yugurish krossovka","ru":"Трейловые кроссовки Pace"}',false,'[{"u":"/photos/trail-1.jpg","c":"#8B6B82"},{"u":"/photos/trail-2.jpg","c":"#8B6B82"},{"u":"/photos/trail-3.jpg","c":"#8B6B82"}]'),
(17,'jackets','training','hoodie','polyester',1290000,0,null,true,'["S","M","L","XL","XXL"]','["#8E2DC6"]','{"uz":"Apex Summit yengil kurtka","ru":"Куртка-ветровка Apex Summit"}',true,'[{"u":"/photos/shell-1.jpg","c":"#8E2DC6"},{"u":"/photos/shell-2.jpg","c":"#8E2DC6"},{"u":"/photos/shell-3.jpg","c":"#8E2DC6"}]'),
(18,'jackets','running','hoodie','fleece',689000,0,null,true,'["S","M","L","XL","XXL"]','["#111111"]','{"uz":"Apex Thermal zip kurtka","ru":"Термокуртка на молнии Apex"}',true,'[{"u":"/photos/zip-1.jpg","c":"#111111"},{"u":"/photos/zip-2.jpg","c":"#111111"},{"u":"/photos/zip-3.jpg","c":"#111111"}]')
on conflict (id) do update set
  cat = excluded.cat, sub = excluded.sub, art = excluded.art, mat = excluded.mat, price = excluded.price,
  sizes = excluded.sizes, colors = excluded.colors, name = excluded.name, is_new = excluded.is_new, photos = excluded.photos;
