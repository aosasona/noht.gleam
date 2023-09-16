import lib/logger
import lib/database
import gleam/int
import gleam/string
import gleam/result
import gleam/erlang/process
import gleam/erlang/os
import api/router
import mist

pub fn main() {
  let port = load_port()
  let db = database.init()

  let assert Ok(_) = database.with_connection(db, database.migrate_schema)

  string.concat(["Starting server on port ", int.to_string(port)])
  |> logger.info

  let handler = router.app(request: _, database: db)

  handler
  |> mist.new
  |> mist.port(port)
  |> mist.start_http

  process.sleep_forever()
}

fn load_port() -> Int {
  os.get_env("PORT")
  |> result.then(int.parse)
  |> result.unwrap(9600)
}
