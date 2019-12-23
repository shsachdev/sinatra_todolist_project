CREATE TABLE lists (id serial PRIMARY KEY, name text NOT NULL UNIQUE);

CREATE TABLE todo (id serial PRIMARY KEY, name text NOT NULL,
                  completed boolean NOT NULL DEFAULT false,
                  list_id int NOT NULL REFERENCES lists (id))
