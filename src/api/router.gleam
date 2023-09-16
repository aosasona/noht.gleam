import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/bit_builder.{BitBuilder}
import gleam/string_builder.{StringBuilder}
import sqlight

pub fn router() -> Response(StringBuilder) {
  todo
}

pub fn app(
  request request: Request(BitString),
  secret secret: String,
  database database: sqlight.Connection,
) -> Response(StringBuilder) {
  todo
}

fn convert_string_body(
  request: Request(BitString),
  next: fn(Request(String)) -> Response(StringBuilder),
) -> Response(BitBuilder) {
  todo
}
