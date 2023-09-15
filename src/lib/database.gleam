import gleam/erlang/os
import gleam/result
import sqlight

fn get_db_path() -> String {
  "DB_PATH"
  |> os.get_env
  |> result.unwrap("noht.db")
}

pub fn with_connection(f: fn(sqlight.Connection) -> a) -> a {
  use db <- sqlight.with_connection(get_db_path())
  // enable foreign keys
  let assert Ok(_) = sqlight.exec("pragma foreign_keys = on;", db)
  f(db)
}

fn migrate(conn: sqlight.Connection) -> sqlight.Connection {
  todo
}
