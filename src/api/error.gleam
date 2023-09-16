import gleam/http/response.{Response}
import gleam/json.{bool, int, object, string, to_string}
import gleam/bit_builder
import mist.{ResponseData}

pub type JSONError = #(Int, String)

pub type ApiError {
  BadRequest
}

fn bad_request() -> JSONError {
  let body =
    object([
      #("ok", bool(False)),
      #("code", int(400)),
      #("message", string("Bad Request")),
    ])
    |> to_string

  #(400, body)
}

pub fn as_response(err: ApiError) -> Response(ResponseData) {
  let #(code, body) = as_json_with_code(err)
  response.new(code)
  |> response.set_body(mist.Bytes(bit_builder.from_string(body)))
}

pub fn as_json_with_code(err: ApiError) -> JSONError {
  case err {
    BadRequest -> bad_request()
  }
}