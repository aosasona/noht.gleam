import api/api.{Context}
import api/error
import api/respond
import api/middleware
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import mist.{Connection, ResponseData}
import sqlight
import handlers/ping.{handle_ping}
import handlers/auth
import handlers/notes

pub fn router(ctx: Context) -> Response(ResponseData) {
  case ctx.path {
    ["ping"] -> handle_ping(ctx)
    ["@me"] | ["me"] -> auth.me(ctx)
    ["auth", ..path] ->
      case path {
        ["sign-up"] -> auth.sign_up(ctx)
        ["sign-in"] -> auth.sign_in(ctx)
      }
    ["notes"] -> notes.handle_root(ctx)
    ["notes", id] -> notes.handle_id(ctx, id)
    _ -> respond.with_err(err: error.NotFound, errors: [])
  }
}

pub fn app(
  request request: Request(Connection),
  database database: sqlight.Connection,
) -> Response(ResponseData) {
  use <- middleware.log_request(request)
  use request <- middleware.convert_body_to_string(request)
  use request <- middleware.authenticate(request, database)
  use request <- middleware.transform_to_api_request(request, database)
  router(request)
}
