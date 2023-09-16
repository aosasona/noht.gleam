import gleam/io
import gleam/string as g_string
import gleam/int as g_int
import gleam/json.{int, object, string}

pub type Level {
  Debug
  Error
  Info
  Warning
}

fn level_as_str(level: Level) -> String {
  case level {
    Debug -> "DEBUG"
    Error -> "ERROR"
    Info -> "INFO"
    Warning -> "WARNING"
  }
}

@external(erlang, "Elixir.DateTime", "utc_now")
fn utc_now() -> Int

@external(erlang, "Elixir.DateTime", "to_unix")
fn to_unix(utc_time: Int) -> Int

pub fn now() -> Int {
  utc_now()
  |> to_unix
}

pub fn format_duration(duration: Int) -> String {
  case duration >= 1000 {
    True -> g_string.append(g_int.to_string(duration), "ms")
    False -> g_string.append(g_int.to_string(duration), "μs")
  }
}

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

pub fn log_request(
  method method: String,
  path path: String,
  duration duration: Int,
  code code: Int,
) {
  let log =
    object([
      #("level", string("INFO")),
      #("method", string(method)),
      #("path", string(path)),
      #("duration", string(format_duration(duration))),
      #("status", int(code)),
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
