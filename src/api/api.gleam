import api/respond
import api/error
import gleam/http
import gleam/http/response.{Response as HttpResponse}
import gleam/option.{None, Option}
import mist.{ResponseData}
import sqlight

pub type Request {
  Request(
    method: http.Method,
    path: List(String),
    headers: List(#(String, String)),
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
