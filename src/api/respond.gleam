import api/error
import gleam/http/response.{Response}
import gleam/bit_builder
import gleam/json.{Json, bool, int, null, object, string, to_string}
import gleam/option.{None, Option, Some}
import mist.{ResponseData}

type NullableJson =
  Option(Json)

fn respond(res: #(Int, String)) -> Response(ResponseData) {
  let #(code, body) = res
  response.new(code)
  |> response.set_header("Content-Type", "application/json")
  |> response.set_body(mist.Bytes(bit_builder.from_string(body)))
}

pub fn with_err(err_type: error.ApiError) -> Response(ResponseData) {
  error.as_json_with_code(err_type)
  |> respond
}

pub fn with_json(
  message message: String,
  data data: NullableJson,
  meta meta: NullableJson,
) -> Response(ResponseData) {
  respond(#(
    200,
    object([
      #("ok", bool(True)),
      #("code", int(200)),
      #("message", string(message)),
      #(
        "data",
        case data {
          Some(data) -> data
          None -> null()
        },
      ),
      #(
        "meta",
        case meta {
          Some(meta) -> meta
          None -> null()
        },
      ),
    ])
    |> to_string,
  ))
}
