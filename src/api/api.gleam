import api/respond
import api/error
import lib/validator.{Field}
import gleam/json
import gleam/dynamic.{Decoder}
import gleam/list
import gleam/string
import gleam/http
import gleam/http/response.{Response as HttpResponse}
import gleam/option.{None, Option, Some}
import mist.{ResponseData}
import sqlight

pub type Context {
  Context(
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
  ctx: Context,
  method: http.Method,
  next: fn() -> HttpResponse(ResponseData),
) -> HttpResponse(ResponseData) {
  case ctx.method == method {
    True -> next()
    False ->
      respond.with_err(
        err: error.MethodNotAllowed(ctx.method, ctx.path),
        errors: [],
      )
  }
}

pub fn require_user(
  ctx: Context,
  next: fn() -> HttpResponse(ResponseData),
) -> HttpResponse(ResponseData) {
  case ctx.user_id {
    Some(_) -> next()
    None -> respond.with_err(err: error.Unauthenticated, errors: [])
  }
}

pub fn require_json(
  ctx: Context,
  next: fn() -> HttpResponse(ResponseData),
) -> HttpResponse(ResponseData) {
  case list.key_find(ctx.headers, "content-type") {
    Ok(value) ->
      case string.lowercase(value) {
        "application/json" -> next()
        _ ->
          respond.with_err(
            err: error.InvalidContentType(
              expected: "application/json",
              provided: value,
            ),
            errors: [],
          )
      }
    Error(_) ->
      respond.with_err(
        err: error.ClientError("No content-type header present in request"),
        errors: [],
      )
  }
}

pub fn to_json(
  ctx: Context,
  decoder: Decoder(a),
  next: fn(a) -> HttpResponse(ResponseData),
) -> HttpResponse(ResponseData) {
  case json.decode(from: ctx.body, using: decoder) {
    Ok(value) -> next(value)
    Error(_) -> {
      respond.with_err(err: error.UnprocessableEntity, errors: [])
    }
  }
}

pub fn validate_body(
  fields: List(Field),
  next: fn() -> HttpResponse(ResponseData),
) -> HttpResponse(ResponseData) {
  let errors =
    validator.validate_many(fields)
    |> validator.to_object

  case list.length(errors) > 0 {
    True ->
      respond.with_err(
        err: error.ClientError("some fields are invalid"),
        errors: errors,
      )
    False -> next()
  }
}
