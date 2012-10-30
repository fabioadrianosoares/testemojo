/*
# sudo -u postgres createuser -D -A -P mojo_user
# -- informar pass mojo_pass
# sudo -u postgres createdb -O mojo_user mojo_db
*/

CREATE TABLE estado (
	sigla CHAR(2) PRIMARY KEY NOT NULL,
	nome VARCHAR(100) NOT NULL);

CREATE TABLE cidade (
	id SERIAL PRIMARY KEY,
	estado CHAR(2) NOT NULL REFERENCES estado (sigla),
	nome VARCHAR(100) NOT NULL);
