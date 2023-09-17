import gleam/json.{bool, int, object, string, to_string}

pub type JSONError =
  #(Int, String)

pub type ApiError {
  BadRequest
  NotFound
  InternalServerError
  CustomError(String, Int)
}

fn make_error(message: String, code: Int) -> JSONError {
  let body =
    object([
      #("ok", bool(False)),
      #("code", int(code)),
      #("error", string(message)),
    ])
    |> to_string

  #(code, body)
}

fn bad_request() -> JSONError {
  make_error("Bad Request", 400)
}

fn not_found() -> JSONError {
  make_error("Not Found", 404)
}

pub fn as_json_with_code(err: ApiError) -> JSONError {
  case err {
    BadRequest -> bad_request()
    NotFound -> not_found()
    CustomError(message, code) -> make_error(message, code)
    _ -> make_error("Internal Server Error", 500)
  }
}
