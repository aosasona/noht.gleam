import api/respond
import api/error.{ApiError}
import lib/logger
import gleam/dynamic.{Decoder}
import gleam/list
import gleam/string
import gleam/http
import gleam/http/response.{Response as HttpResponse}
import gleam/option.{None, Option, Some}
import mist.{ResponseData}
import sqlight

pub type Request {
  Request(
    headers: List(#(String, String)),
    method: http.Method,
    path: List(String),
    body: String,
    db: sqlight.Connection,
    user_id: Option(Int),
  )
}

// https://github.com/lpil/wisp/blob/aaeae8da058f732bdb17c1d99761326bb0c1a0e5/src/wisp.gleam#L683
pub fn require_method(
  request: Request,
  method: http.Method,
  next: fn() -> HttpResponse(ResponseData),
) -> HttpResponse(ResponseData) {
  case request.method == method {
    True -> next()
    False ->
      respond.with_err(
        err: error.MethodNotAllowed(request.method, request.path),
        errors: None,
      )
  }
}

pub fn require_user(
  request: Request,
  next: fn() -> HttpResponse(ResponseData),
) -> HttpResponse(ResponseData) {
  case request.user_id {
    Some(_) -> next()
    None -> respond.with_err(err: error.Unauthenticated, errors: None)
  }
}

pub fn require_json(
  request: Request,
  next: fn() -> HttpResponse(ResponseData),
) -> HttpResponse(ResponseData) {
  case list.key_find(request.headers, "content-type") {
    Ok(value) ->
      case string.lowercase(value) {
        "application/json" -> next()
        _ ->
          respond.with_err(
            err: error.InvalidContentType(
              expected: "application/json",
              provided: value,
            ),
            errors: None,
          )
      }
    Error(_) ->
      respond.with_err(
        err: error.ClientError("No content-type header present in request"),
        errors: None,
      )
  }
}

pub fn to_json(request: Request, to target: Decoder(a)) -> Result(a, ApiError) {
  todo
}
