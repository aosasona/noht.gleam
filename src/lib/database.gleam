import gleam/erlang/os
import gleam/result
import api/error.{ApiError}
import sqlight

fn get_db_path() -> String {
  "DB_PATH"
  |> os.get_env
  |> result.unwrap("noht.db")
}

pub fn init() -> sqlight.Connection {
  let assert Ok(db) = sqlight.open("file:" <> get_db_path())

  // enable foreign keys
  let assert Ok(_) = sqlight.exec("pragma foreign_keys = on;", db)
  db
}

pub fn with_connection(
  db: sqlight.Connection,
  f: fn(sqlight.Connection) -> a,
) -> a {
  f(db)
}

pub fn migrate_schema(db: sqlight.Connection) -> Result(Nil, ApiError) {
  // `0` as a folder_id means it is uncategorized
  sqlight.exec(
    "
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      username TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL,
      created_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS folders (
      id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      name TEXT NOT NULL,
      user_id INTEGER NOT NULL,
      parent_id INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users (id),
      FOREIGN KEY (parent_id) REFERENCES folders (id)
    );

    CREATE TABLE IF NOT EXISTS notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      folder_id INTEGER NOT NULL DEFAULT 0,
      user_id INTEGER NOT NULL,
      created_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users (id),
      FOREIGN KEY (folder_id) REFERENCES folders (id)
    );

    CREATE TABLE IF NOT EXISTS _auth_tokens (
      id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      user_id INTEGER NOT NULL,
      token TEXT NOT NULL,
      issued_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP,
      last_used_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users (id),
      UNIQUE (token)
    );
    ",
    db,
  )
  |> result.map_error(error.SqlightError)
}
