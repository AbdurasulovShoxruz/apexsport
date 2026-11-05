-- APEX SPORT update for an EXISTING database: photos for the second batch (windbreaker, tote, bucket hat, shorts, jogger pants, hoodie).
-- Run AFTER supabase-update-photos.sql. SQL Editor -> New query -> paste everything -> Run. Safe to run again.
-- (New installs do not need this file: supabase.sql already contains everything.)

-- 1) New colour used by the hoodie
insert into shop_colors (hex, name, pos) values
  ('#D9D3D0', 'Bej', 16)
on conflict (hex) do nothing;

-- 2) Photos for products that already exist (2 hoodie, 3 shorts, 9 jogger pants). Stock and discount you set are kept.
update shop_products set colors = '["#111111","#6B7280","#1F3A5F","#D9D3D0"]', photos = '[{"u":"/photos/hoodie-2.jpg","c":"#D9D3D0"},{"u":"/photos/hoodie-3.jpg","c":"#D9D3D0"},{"u":"/photos/hoodie-1.jpg","c":"#D9D3D0"}]' where id = 2;
update shop_products set photos = '[{"u":"/photos/shorts-1.jpg","c":"#111111"},{"u":"/photos/shorts-2.jpg","c":"#111111"},{"u":"/photos/shorts-3.jpg","c":"#111111"}]' where id = 3;
update shop_products set photos = '[{"u":"/photos/fleece-pants-4.jpg","c":"#111111"},{"u":"/photos/fleece-pants-3.jpg","c":"#111111"},{"u":"/photos/fleece-pants-2.jpg","c":"#111111"},{"u":"/photos/fleece-pants-1.jpg","c":"#111111"},{"u":"/photos/fleece-pants-5.jpg","c":"#111111"}]' where id = 9;

-- 3) New products 19-21: windbreaker, tote bag, bucket hat
insert into shop_products (id,cat,sub,art,mat,price,sale,stock,active,sizes,colors,name,is_new,photos) values
(19,'jackets','running','coat','polyester',899000,0,null,true,'["S","M","L","XL","XXL"]','["#111111"]','{"uz":"Apex Trail shamolga chidamli kurtka","ru":"Ветровка Apex Trail"}',true,'[{"u":"/photos/windbreaker-1.jpg","c":"#111111"},{"u":"/photos/windbreaker-2.jpg","c":"#111111"},{"u":"/photos/windbreaker-3.jpg","c":"#111111"},{"u":"/photos/windbreaker-5.jpg","c":"#111111"}]'),
(20,'accessories','bags','tote','polyester',349000,0,null,true,null,'["#111111"]','{"uz":"Apex Gear tote sumkasi","ru":"Сумка-тоут Apex Gear"}',true,'[{"u":"/photos/tote-2.jpg","c":"#111111"},{"u":"/photos/tote-3.jpg","c":"#111111"},{"u":"/photos/tote-1.jpg","c":"#111111"}]'),
(21,'accessories','caps','cap','mesh',129000,0,null,true,null,'["#FFFFFF"]','{"uz":"Apex Trail panama","ru":"Панама Apex Trail"}',true,'[{"u":"/photos/bucket-hat-2.jpg","c":"#FFFFFF"},{"u":"/photos/bucket-hat-1.jpg","c":"#FFFFFF"}]')
on conflict (id) do update set
  cat = excluded.cat, sub = excluded.sub, art = excluded.art, mat = excluded.mat, price = excluded.price,
  sizes = excluded.sizes, colors = excluded.colors, name = excluded.name, is_new = excluded.is_new, photos = excluded.photos;
