import api/api
import api/respond
import gleam/http.{Get}
import gleam/http/response.{Response}
import gleam/option.{None}
import mist.{ResponseData}

pub fn handle_ping(request: api.Request) -> Response(ResponseData) {
  use <- api.require_method(request, Get)
  respond.with_json(message: "pong", data: None, meta: None)
}
