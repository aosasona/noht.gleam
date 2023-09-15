import gleam/io
import gleam/json.{int, object, string}

pub type Level {
  Debug
  Error
  Info
  Warning
}

fn level_as_str(level: Level) -> String {
  case level {
    Debug -> "debug"
    Error -> "error"
    Info -> "info"
    Warning -> "warning"
  }
}

@external(erlang, "Elixir.DateTime", "utc_now")
fn utc_now() -> Int

@external(erlang, "Elixir.DateTime", "to_unix")
fn to_unix(utc_time: Int) -> Int

pub fn log(level: Level, message: String) {
  let log =
    object([
      #("level", string(level_as_str(level))),
      #("message", string(message)),
      #(
        "timestamp",
        int(
          utc_now()
          |> to_unix,
        ),
      ),
    ])
    |> json.to_string

  io.println(log)
}

pub fn debug(message: String) {
  log(Debug, message)
}

pub fn error(message: String) {
  log(Error, message)
}

pub fn info(message: String) {
  log(Info, message)
}

pub fn warning(message: String) {
  log(Warning, message)
}
