import lib/database
import gleam/int
import gleam/result
import gleam/erlang/process
import gleam/erlang/os
import api/router
import mist
import sqlight

pub fn main() {
  let port = load_port()
  let db = database.init()

  let assert Ok(_) = database.with_connection(db, database.migrate_schema)

  router.app(request: _, database: db)
  |> mist.new
  |> mist.port(port)
  |> mist.start_http

  // this is required to put the main process to sleep so that the server can keep handling requests
  process.sleep_forever()
}

fn load_port() -> Int {
  os.get_env("PORT")
  |> result.then(int.parse)
  |> result.unwrap(9600)
}
