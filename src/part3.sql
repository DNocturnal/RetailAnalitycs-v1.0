--создание группы Администратор

CREATE ROLE Administrator WITH NOLOGIN
NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;

-- добавление прав группе Администратор
GRANT USAGE ON SCHEMA enter_database_name TO Administrator;
GRANT SELECT, INSERT, UPDATE, DELETE
     ON ALL TABLES IN SCHEMA enter_database_name TO Administrator;

--создание новой роли, которая будет входить в группу Админситратор

CREATE ROLE enter_new_role LOGIN
ENCRYPTED PASSWORD 'enter password here'
NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT IN ROLE Administrator;

--создание группы Посетитель
CREATE ROLE Visitor WITH NOLOGIN
NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;

--  добавление прав группе Посетитель
GRANT USAGE ON SCHEMA enter_database_name TO Administrator;
GRANT SELECT ON ALL TABLES IN SCHEMA enter_database_name TO Visitor;

--создание новой роли, которая будет входить в группу Посетитель

CREATE ROLE enter_new_role LOGIN
ENCRYPTED PASSWORD 'enter password here'
NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT IN ROLE Visitor;