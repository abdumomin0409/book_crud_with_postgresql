--
-- PostgreSQL database dump
--

-- Dumped from database version 14.7 (Ubuntu 14.7-0ubuntu0.22.04.1)
-- Dumped by pg_dump version 14.7 (Ubuntu 14.7-0ubuntu0.22.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: crud; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA crud;


ALTER SCHEMA crud OWNER TO postgres;

--
-- Name: helper; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA helper;


ALTER SCHEMA helper OWNER TO postgres;

--
-- Name: mapper; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA mapper;


ALTER SCHEMA mapper OWNER TO postgres;

--
-- Name: utils; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA utils;


ALTER SCHEMA utils OWNER TO postgres;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA utils;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: create_book_dto; Type: TYPE; Schema: utils; Owner: postgres
--

CREATE TYPE utils.create_book_dto AS (
	name character varying,
	author character varying,
	price integer,
	pages integer,
	category_id integer
);


ALTER TYPE utils.create_book_dto OWNER TO postgres;

--
-- Name: update_book_dto; Type: TYPE; Schema: utils; Owner: postgres
--

CREATE TYPE utils.update_book_dto AS (
	id integer,
	name character varying,
	author character varying,
	price integer,
	pages integer,
	category_id integer
);


ALTER TYPE utils.update_book_dto OWNER TO postgres;

--
-- Name: book_create(text); Type: FUNCTION; Schema: crud; Owner: postgres
--

CREATE FUNCTION crud.book_create(book_param text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
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
    insert into public.book(name, author, create_at , price, pages, category_id)
    VALUES (data.name, data.author, current_timestamp , data.price, data.pages, data.category_id)
    returning id into return_id;
    return return_id;
end
$$;


ALTER FUNCTION crud.book_create(book_param text) OWNER TO postgres;

--
-- Name: book_delete(integer); Type: FUNCTION; Schema: crud; Owner: postgres
--

CREATE FUNCTION crud.book_delete(deleted_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION crud.book_delete(deleted_id integer) OWNER TO postgres;

--
-- Name: book_get_all(); Type: FUNCTION; Schema: crud; Owner: postgres
--

CREATE FUNCTION crud.book_get_all() RETURNS text
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION crud.book_get_all() OWNER TO postgres;

--
-- Name: book_get_by_id(integer); Type: FUNCTION; Schema: crud; Owner: postgres
--

CREATE FUNCTION crud.book_get_by_id(book_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION crud.book_get_by_id(book_id integer) OWNER TO postgres;

--
-- Name: book_update(text); Type: FUNCTION; Schema: crud; Owner: postgres
--

CREATE FUNCTION crud.book_update(data_params text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION crud.book_update(data_params text) OWNER TO postgres;

--
-- Name: category_create(character varying); Type: FUNCTION; Schema: crud; Owner: postgres
--

CREATE FUNCTION crud.category_create(name character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION crud.category_create(name character varying) OWNER TO postgres;

--
-- Name: category_delete(integer); Type: FUNCTION; Schema: crud; Owner: postgres
--

CREATE FUNCTION crud.category_delete(c_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION crud.category_delete(c_id integer) OWNER TO postgres;

--
-- Name: category_get(integer); Type: FUNCTION; Schema: crud; Owner: postgres
--

CREATE FUNCTION crud.category_get(category_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    return coalesce(((select (json_build_object('id', c.id, 'name', c.name, 'active', c.active))
                      from public.category c
                      where c.active = true
                        and c.id = category_id)::text), '[]');
end
$$;


ALTER FUNCTION crud.category_get(category_id integer) OWNER TO postgres;

--
-- Name: category_get_all(); Type: FUNCTION; Schema: crud; Owner: postgres
--

CREATE FUNCTION crud.category_get_all() RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    return coalesce(((select json_agg(json_build_object('id', c.id, 'name', c.name, 'active', c.active))
                      from public.category c
                      where c.active = true)::text), '[]');
end;
$$;


ALTER FUNCTION crud.category_get_all() OWNER TO postgres;

--
-- Name: category_update(text); Type: FUNCTION; Schema: crud; Owner: postgres
--

CREATE FUNCTION crud.category_update(data_param text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION crud.category_update(data_param text) OWNER TO postgres;

--
-- Name: check_varchar_param(character varying, character varying); Type: PROCEDURE; Schema: helper; Owner: postgres
--

CREATE PROCEDURE helper.check_varchar_param(IN param character varying, IN param_name character varying)
    LANGUAGE plpgsql
    AS $$
begin
    if param is null or trim(param) ilike '' then
        raise exception '% should not be null ', param_name;
    end if;
end
$$;


ALTER PROCEDURE helper.check_varchar_param(IN param character varying, IN param_name character varying) OWNER TO postgres;

--
-- Name: json_to_create_book_dto(json); Type: FUNCTION; Schema: mapper; Owner: postgres
--

CREATE FUNCTION mapper.json_to_create_book_dto(json_data json) RETURNS utils.create_book_dto
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION mapper.json_to_create_book_dto(json_data json) OWNER TO postgres;

--
-- Name: json_to_update_book_dto(json); Type: FUNCTION; Schema: mapper; Owner: postgres
--

CREATE FUNCTION mapper.json_to_update_book_dto(json_data json) RETURNS utils.update_book_dto
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION mapper.json_to_update_book_dto(json_data json) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: book; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.book (
    id integer NOT NULL,
    name character varying NOT NULL,
    author character varying NOT NULL,
    create_at timestamp(0) with time zone,
    price integer NOT NULL,
    pages integer NOT NULL,
    category_id integer
);


ALTER TABLE public.book OWNER TO postgres;

--
-- Name: book_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.book_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.book_id_seq OWNER TO postgres;

--
-- Name: book_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.book_id_seq OWNED BY public.book.id;


--
-- Name: category; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.category (
    id integer NOT NULL,
    name character varying NOT NULL,
    active boolean DEFAULT true
);


ALTER TABLE public.category OWNER TO postgres;

--
-- Name: category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.category_id_seq OWNER TO postgres;

--
-- Name: category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.category_id_seq OWNED BY public.category.id;


--
-- Name: book id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.book ALTER COLUMN id SET DEFAULT nextval('public.book_id_seq'::regclass);


--
-- Name: category id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.category ALTER COLUMN id SET DEFAULT nextval('public.category_id_seq'::regclass);


--
-- Data for Name: book; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.book (id, name, author, create_at, price, pages, category_id) FROM stdin;
5	Men aybdorman	Sulaymon	2023-03-31 14:56:30+05	136000	993	2
3	Talabalikda	Abdumomin	\N	150000	99	1
4	Meni kutish qiyinmas	Abdumomin	2023-03-31 14:53:11+05	150000	99	1
\.


--
-- Data for Name: category; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.category (id, name, active) FROM stdin;
1	Hayotiy	t
2	Badiiy	t
\.


--
-- Name: book_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.book_id_seq', 5, true);


--
-- Name: category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.category_id_seq', 2, true);


--
-- Name: book book_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.book
    ADD CONSTRAINT book_pkey PRIMARY KEY (id);


--
-- Name: category category_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT category_pkey PRIMARY KEY (id);


--
-- Name: book book_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.book
    ADD CONSTRAINT book_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.category(id);


--
-- PostgreSQL database dump complete
--

