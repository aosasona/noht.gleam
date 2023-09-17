import api/respond
import gleam/http/response.{Response}
import gleam/option.{None}
import mist.{ResponseData}

pub fn handle_ping() -> Response(ResponseData) {
  respond.with_json(message: "pong", data: None, meta: None)
}
