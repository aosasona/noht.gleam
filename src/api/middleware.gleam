import api/error
import api/api
import lib/logger
import gleam/http
import gleam/string
import gleam/int
import gleam/bit_string
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/option.{None, Option, Some}
import gleam/result
import sqlight
import mist.{Connection, ResponseData}
import api/respond

pub fn log_request(
  request: Request(_),
  next: fn() -> Response(a),
) -> Response(a) {
  let before = logger.now()
  let response = next()
  logger.log_request(
    code: response.status,
    method: request.method
    |> http.method_to_string
    |> string.uppercase,
    path: request.path,
    duration: logger.now() - before,
  )
  response
}

pub fn convert_string_body(
  request: Request(Connection),
  next: fn(Request(String)) -> Response(ResponseData),
) -> Response(ResponseData) {
  case mist.read_body(request, 1024 * 1024 * 32) {
    Ok(req) -> {
      case bit_string.to_string(req.body) {
        Ok(body) -> {
          request
          |> request.set_body(body)
          |> next
        }
        Error(_) -> respond.with_err(err: error.BadRequest, errors: None)
      }
    }
    Error(_) -> respond.with_err(err: error.BadRequest, errors: None)
  }
}

// TODO: handle authentication properly i.e only allow sessions younger than 14 days or last used within the last 5 days
pub fn authenticate(
  request: Request(String),
  _db: sqlight.Connection,
  next: fn(#(Request(String), Option(Int))) -> Response(ResponseData),
) -> Response(ResponseData) {
  let user_id: Option(Int) = case request.get_header(request, "Authorization") {
    Ok(uid) ->
      uid
      |> int.parse
      |> result.unwrap(or: 0)
      |> Some
    Error(_) -> None
  }

  case user_id {
    Some(uid) -> {
      next(#(request, Some(uid)))
    }
    None -> next(#(request, None))
  }
}

pub fn transform_to_api_request(
  request_with_auth: #(Request(String), Option(Int)),
  db: sqlight.Connection,
  next: fn(api.Request) -> Response(ResponseData),
) -> Response(ResponseData) {
  let #(request, user_id) = request_with_auth

  next(api.Request(
    method: request.method,
    headers: request.headers,
    path: request.path_segments(request),
    body: request.body,
    db: db,
    user_id: user_id,
  ))
}
