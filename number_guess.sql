SET client_min_messages TO WARNING;

CREATE TABLE IF NOT EXISTS users (
  user_id SERIAL PRIMARY KEY,
  username VARCHAR(22) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS games (
  game_id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(user_id),
  number_of_guesses INTEGER NOT NULL CHECK (number_of_guesses > 0)
);
