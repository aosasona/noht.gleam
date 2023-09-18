import api/api
import api/error
import api/respond
import api/middleware
import handlers/ping.{handle_ping}
import handlers/auth
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/option.{None}
import mist.{Connection, ResponseData}
import sqlight

pub fn router(req: api.Request) -> Response(ResponseData) {
  case req.path {
    ["ping"] -> handle_ping(req)
    ["auth", ..path] ->
      case path {
        ["sign-up"] -> auth.sign_up(req)
        ["sign-in"] -> auth.sign_in(req)
      }
    _ -> respond.with_err(err: error.NotFound, errors: None)
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
