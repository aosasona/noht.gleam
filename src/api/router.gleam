import api/api
import api/respond
import api/error
import api/middleware
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import mist.{Connection, ResponseData}
import gleam/option.{None}
import sqlight

pub fn router(request: api.Request) -> Response(ResponseData) {
  case request.path {
    ["ping"] -> respond.with_json(message: "pong", data: None, meta: None)
    _ -> respond.with_err(error.NotFound)
  }
}

pub fn app(
  request request: Request(Connection),
  database database: sqlight.Connection,
) -> Response(ResponseData) {
  use <- middleware.log_request(request)
  use request <- middleware.convert_string_body(request)
  use request <- middleware.authenticate(request, database)
  use request <- middleware.transform_to_api_request(request, database)
  router(request)
}
