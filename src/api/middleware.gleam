import api/error
import api/api.{Context}
import lib/token
import lib/logger
import gleam/http
import gleam/string
import gleam/bit_string
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/option.{None, Option, Some}
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

pub fn convert_body_to_string(
  request: Request(Connection),
  next: fn(Request(String)) -> Response(ResponseData),
) -> Response(ResponseData) {
  case mist.read_body(request, 1024 * 1024 * 16) {
    Ok(req) -> {
      case bit_string.to_string(req.body) {
        Ok(body) -> {
          request
          |> request.set_body(body)
          |> next
        }
        Error(_) -> respond.with_err(err: error.BadRequest, errors: [])
      }
    }
    Error(_) -> respond.with_err(err: error.BadRequest, errors: [])
  }
}

pub fn authenticate(
  request: Request(String),
  db: sqlight.Connection,
  next: fn(#(Request(String), Option(Int))) -> Response(ResponseData),
) -> Response(ResponseData) {
  let auth_token = case request.get_header(request, "Authorization") {
    Ok(tk) -> Some(tk)
    Error(_) -> None
  }

  let uid = case auth_token {
    Some(auth_token) -> {
      case token.verify(db: db, token: auth_token) {
        Ok(user) -> Some(user.id)
        Error(_) -> None
      }
    }
    None -> None
  }

  case uid {
    Some(uid) -> {
      next(#(request, Some(uid)))
    }
    None -> next(#(request, None))
  }
}

pub fn transform_to_api_request(
  request_with_auth: #(Request(String), Option(Int)),
  db: sqlight.Connection,
  next: fn(Context) -> Response(ResponseData),
) -> Response(ResponseData) {
  let #(request, user_id) = request_with_auth

  next(Context(
    headers: request.headers,
    method: request.method,
    path: request.path_segments(request),
    body: request.body,
    db: db,
    user_id: user_id,
  ))
}
