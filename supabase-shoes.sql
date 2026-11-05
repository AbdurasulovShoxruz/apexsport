-- APEX SPORT: add the SHOES category and 3 demo shoe products to an EXISTING database.
-- Run once in Supabase: SQL Editor -> New query -> paste -> Run. Safe to run again.
-- (New installs do not need this file: supabase.sql already contains shoes.)

insert into shop_sections (key, kind, uz, ru, pos) values
  ('shoes', 'cat', 'Oyoq kiyim', 'Обувь', 6)
on conflict (key) do nothing;

insert into shop_products (id,cat,sub,art,mat,price,sale,stock,active,sizes,colors,name,is_new) values
(14,'shoes','running','sneaker','mesh',649000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#111111","#FFFFFF","#FF5B1F"]','{"uz":"Apex Runner krossovka","ru":"Кроссовки Apex Runner"}',true),
(15,'shoes','training','sneaker','synthetic',589000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#111111","#6B7280"]','{"uz":"Peak Trainer krossovka","ru":"Кроссовки Peak Trainer"}',false),
(16,'shoes','lifestyle','boot','leather',729000,0,null,true,'["39","40","41","42","43","44","45","46"]','["#3F5B3A","#111111"]','{"uz":"Summit trail botinka","ru":"Трекинговые ботинки Summit"}',false)
on conflict (id) do nothing;
