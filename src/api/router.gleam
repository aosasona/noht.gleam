import api/api
import api/middleware
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/string_builder.{StringBuilder}
import mist.{Connection, ResponseData}
import sqlight

pub fn router(request: api.Request) -> Response(ResponseData) {
  todo
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
