#!/bin/bash

set -euo pipefail

database_name=number_guess
database_user=freecodecamp
script_directory=$(dirname -- "${BASH_SOURCE[0]}")

database_exists=$(psql --username="$database_user" --dbname=postgres --no-align --tuples-only --no-psqlrc --command="SELECT 1 FROM pg_database WHERE datname = '$database_name';")
if [[ -z "$database_exists" ]]; then
  createdb --username="$database_user" "$database_name"
fi

psql --username="$database_user" --dbname="$database_name" --no-psqlrc --quiet --set=ON_ERROR_STOP=1 --file="$script_directory/number_guess.sql"

psql_command=(psql --username="$database_user" --dbname="$database_name" --no-align --tuples-only --no-psqlrc --quiet --set=ON_ERROR_STOP=1)

printf 'Enter your username: '
IFS= read -r username

user_id=$(
  "${psql_command[@]}" --set=username="$username" <<'SQL'
INSERT INTO users (username)
VALUES (:'username')
ON CONFLICT (username) DO NOTHING
RETURNING user_id;
SQL
)

if [[ -n "$user_id" ]]; then
  printf 'Welcome, %s! It looks like this is your first time here.\n' "$username"
else
  user_id=$(
    "${psql_command[@]}" --set=username="$username" <<'SQL'
SELECT user_id FROM users WHERE username = :'username';
SQL
  )
  user_stats=$(
    "${psql_command[@]}" --set=user_id="$user_id" <<'SQL'
    SELECT COUNT(g.game_id) || '|' || COALESCE(MIN(g.number_of_guesses), 0)
    FROM games AS g
    WHERE g.user_id = :user_id;
SQL
  )
  IFS='|' read -r games_played best_game <<< "$user_stats"
  printf 'Welcome back, %s! You have played %s games, and your best game took %s guesses.\n' "$username" "$games_played" "$best_game"
fi

secret_number=$(( RANDOM % 1000 + 1 ))
number_of_guesses=0

printf 'Guess the secret number between 1 and 1000: '
while IFS= read -r guess; do
  if [[ ! "$guess" =~ ^[+-]?[0-9]+$ ]]; then
    printf 'That is not an integer, guess again: '
    continue
  fi

  if [[ "$guess" == -* ]]; then
    guess_number=$(( -10#${guess#-} ))
  elif [[ "$guess" == +* ]]; then
    guess_number=$(( 10#${guess#+} ))
  else
    guess_number=$(( 10#$guess ))
  fi

  number_of_guesses=$((number_of_guesses + 1))
  if (( guess_number > secret_number )); then
    printf "It's lower than that, guess again: "
  elif (( guess_number < secret_number )); then
    printf "It's higher than that, guess again: "
  else
    "${psql_command[@]}" --set=user_id="$user_id" --set=number_of_guesses="$number_of_guesses" >/dev/null <<'SQL'
INSERT INTO games (user_id, number_of_guesses) VALUES (:user_id, :number_of_guesses);
SQL
    printf 'You guessed it in %s tries. The secret number was %s. Nice job!\n' "$number_of_guesses" "$secret_number"
    sleep 0.1
    break
  fi
done
