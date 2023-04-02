
create table book
(
id          serial primary key,
name        varchar not null,
author      varchar not null,
create_at   timestamp(0) with time zone,
price       int     not null,
pages       int     not null,
category_id int references category (id)
);  -- create book table

create table category
(
id     serial primary key,
name   varchar not null,
active boolean default true
);  -- create category table


set search_path to book_crud, helper;
create procedure check_varchar_param(param varchar, param_name varchar)
language plpgsql as
$$
begin
if param is null or trim(param) ilike '' then
raise exception '% should not be null ', param_name;
end if;
end
$$;  -- checks optional parameter is valid or invalid 
call check_varchar_param('  ', 'name'); 


create function category_create(name varchar) returns int
language plpgsql as
$$
declare
data_json jsonb;
v_name    varchar;
new_name  varchar;
new_id    int;
BEGIN
if name is null or name = '{}'::text or trim(name) = '' then
raise exception 'Name should not be null or empty ';
end if;
data_json := name :: json;
v_name := data_json ->> 'name';
if exists(select * from public.category c where c.name ilike v_name and c.active = true) then
raise exception '% is already exists' , v_name;
end if;
new_name := trim(v_name);
insert into public.category(name) values (new_name) returning id into new_id;
return new_id;
end
$$;  -- creates category if all right or else return exception
set search_path to book_crud, crud;
select category_create('{"name" : "Xorijiy"}');
select *
from public.category;


create function category_delete(c_id int) returns bool
language plpgsql as
$$
declare
v_category record;
BEGIN
if c_id = 0 then
raise exception 'Id should not be nol';
end if;
select * into v_category from public.category c where c.id = c_id and c.active = true;
if not FOUND then
raise exception 'This % id is not found ', c_id;
end if;
update public.category set active = false where id = c_id;
return true;
end
$$;  -- delete category if all right or else return exception
select category_delete(5);
select *
from public.category;


set search_path to book_crud, crud;
create function category_update(data_param text) returns boolean
language plpgsql as
$$
declare
json_data    json;
c_name       varchar;
c_id         int;
old_category record;
BEGIN
if data_param is null or data_param = '{}'::text or trim(data_param) = '' then
raise exception 'Parameter can not be null or empty ';
end if;
json_data := data_param ::json;
c_id := json_data ->> 'id';
c_name := json_data ->> 'name';
if c_id <= 0 then
raise exception 'this category id (%) is not found', c_id;
end if;
if c_name is null then
raise exception 'updating category name is null';
end if;
select * into old_category from public.category where id = c_id;
if not FOUND then
raise exception 'category id (%) is not found', c_id;
end if;
update public.category c set name = c_name where c.id = c_id;
return true;
end
$$;  -- updates category with given fields  if all right or else return exception
select category_update('{
"id" : 2,
"name" : "Badiiy"
}');
select *
from public.category;


set search_path to book_crud, crud;
create function category_get(category_id int) returns text
language plpgsql as
$$
BEGIN
return coalesce(((select (json_build_object('id', c.id, 'name', c.name, 'active', c.active))
from public.category c
where c.active = true
and c.id = category_id)::text), '[]');
end
$$;  -- get category by id
select category_get(3);
select *
from public.category;


set search_path to book_crud, crud;
create function category_get_all() returns text
language plpgsql as
$$
BEGIN
return coalesce(((select json_agg(json_build_object('id', c.id, 'name', c.name, 'active', c.active))
from public.category c
where c.active = true)::text), '[]');
end;
$$;  -- -- to get all category from database
select category_get_all();
select *
from public.category;

set search_path to book_crud, utils;
create type create_book_dto as
(
name        varchar,
author      varchar,
price       int,
pages       int,
category_id int
);  -- create type(book_create_dto) for created book


set search_path to book_crud, mapper;
create function json_to_create_book_dto(json_data json) returns utils.create_book_dto
language plpgsql as
$$
declare
data utils.create_book_dto;
BEGIN
data.name := json_data ->> 'name';
data.author := json_data ->> 'author';
data.price := json_data ->> 'price';
data.pages := json_data ->> 'pages';
data.category_id := json_data ->> 'category_id';
return data;
end
$$;  -- get category with all fields from json



set search_path to book_crud, crud;
create function book_create(book_param text) returns int
language plpgsql as
$$
declare
json_data    json;
data         utils.create_book_dto;
return_id    int;
old_category record;
BEGIN
if book_param is null or trim(book_param) ilike '' or book_param = '{}'::text then
raise exception 'Parameter can not be null';
end if;
json_data := book_param::json;
data := mapper.json_to_create_book_dto(json_data);
call helper.check_varchar_param(data.name, 'name');
call helper.check_varchar_param(data.author, 'author');
if data.price <= 0 then
raise exception 'price should be bigger then 0';
end if;
if data.pages <= 0 then
raise exception 'pages should be bigger then 0';
end if;
if exists(select * from public.book where name ilike data.name) then
raise exception ' this name (%) is already exists', data.name;
end if;
select * into old_category from public.category where id = data.category_id and active = true;
if not FOUND then
raise exception 'this category id (%) is not found', data.category_id;
end if;
insert into public.book(name, author, create_at, price, pages, category_id)
VALUES (data.name, data.author, current_timestamp, data.price, data.pages, data.category_id)
returning id into return_id;
return return_id;
end
$$;  -- creates book if all right or else return exception
insert into public.category(name)
values ('BAdiiy');
select book_create('{
"name" : "Men aybdorman",
"author" : "Sulaymon",
"price" : 136000,
"pages" : 993,
"category_id" : 2
}');
select *
from public.book;


set search_path to book_crud, crud;
create function book_delete(deleted_id int) returns boolean
language plpgsql as
$$
declare
old_book record;
BEGIN
if deleted_id <= 0 then
raise exception 'this number (%) can not be 0 or minus', deleted_id ;
end if;
select * into old_book from public.book where id = deleted_id;
if not FOUND then
raise exception 'this book id (%) is not found', deleted_id;
end if;
delete from public.book where id = deleted_id;
return true;
end
$$;  -- delete book if all right or else return exception
select book_delete(2);
select *
from public.book;


set search_path to book_crud, utils;
create type update_book_dto as
(
id          int,
name        varchar,
author      varchar,
price       int,
pages       int,
category_id int
);  -- create type(book_update_dto) for updated book 


set search_path to book_crud, mapper;
create function json_to_update_book_dto(json_data json) returns utils.update_book_dto
language plpgsql as
$$
declare
data utils.update_book_dto;
BEGIN
data.id := json_data ->> 'id';
data.name := json_data ->> 'name';
data.author := json_data ->> 'author';
data.price := json_data ->> 'price';
data.pages := json_data ->> 'pages';
data.category_id := json_data ->> 'category_id';
return data;
end;
$$;  -- get book with all fields from json


set search_path to book_crud, crud;
create function book_update(data_params text) returns boolean
language plpgsql as
$$
declare
old_book  record;
json_data json;
old_cate  record;
dto       utils.update_book_dto;
BEGIN
if data_params is null or data_params = '{}'::text then
raise exception 'Parameter is null or empty';
end if;
json_data := data_params :: json;
dto := mapper.json_to_update_book_dto(json_data);
select * into old_book from public.book where id = dto.id;
if not found then
raise exception 'this book id (%) is not found', dto.id;
end if;
if dto.name is null then
dto.name := old_book.name;
end if;
if dto.author is null then
dto.author := old_book.author;
end if;
if dto.price is null then
dto.price := old_book.price;
end if;
if dto.pages is null then
dto.pages := old_book.pages;
end if;
if dto.category_id is null then
dto.category_id := old_book.category_id;
end if;

    select * into old_cate from public.category where id = dto.category_id;
    if not FOUND then
        raise exception 'this category id (%) is not found', dto.category_id;
    end if;
    update public.book a
    set name        = dto.name,
        author      = dto.author,
        price       = dto.price,
        pages       = dto.pages,
        create_at   = current_timestamp,
        category_id = dto.category_id
    where a.id = dto.id;
    return true;
end
$$;   -- updates book with given fields  if all right or else return exception
select book_update('{
"id" : 4,
"name" : "Meni kutish qiyinmas",
"author" : "Mustafo",
"price" : 150000,
"pages" : 99,
"category_id" : 1
}');
select *
from public.book;


set search_path to book_crud, crud;
create function book_get_by_id(book_id int) returns text
language plpgsql as
$$
BEGIN
return coalesce(
((select (json_build_object(
'id', b.id,
'name', b.name,
'author', b.author,
'price', b.price,
'pages', b.pages,
'created_at', b.create_at,
'category_id', b.category_id
))
from public.book b
where b.id = book_id)::text), '[]');
end
$$;  -- get book by id 
select book_get_by_id(5);
select *
from public.book;


set search_path to book_crud, crud;
create function book_get_all() returns text
language plpgsql as
$$
BEGIN
return coalesce(((select json_agg(json_build_object('id', b.id,
'name', b.name,
'author', b.author,
'price', b.price,
'pages', b.pages,
'created_at', b.create_at,
'category_id', b.category_id))
from public.book b)::text), '[]');
end;
$$;  -- to get all books from database
select book_get_all();