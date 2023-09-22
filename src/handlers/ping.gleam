import api/api.{Context}
import api/respond
import gleam/http.{Get}
import gleam/http/response.{Response}
import gleam/option.{None}
import mist.{ResponseData}

pub fn handle_ping(ctx: Context) -> Response(ResponseData) {
  use <- api.require_method(ctx, Get)
  respond.with_json(message: "pong", data: None, meta: None)
}
