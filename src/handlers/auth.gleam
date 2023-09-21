import api/api
import api/error
import api/respond
// import lib/schemas/user.{Email}
import gleam/string
import gleam/dynamic
import gleam/http.{Post}
import gleam/http/response.{Response}
import gleam/option.{None}
import mist.{ResponseData}

type SignUpSchema {
  SignUpSchema(
    username: String,
    email: String,
    password: String,
    confirm_password: String,
  )
}

pub fn sign_up(request: api.Request) -> Response(ResponseData) {
  use <- api.require_method(request, Post)
  use <- api.require_json(request)

  let schema_decoder =
    dynamic.decode4(
      SignUpSchema,
      dynamic.field("username", dynamic.string),
      dynamic.field("email", dynamic.string),
      dynamic.field("password", dynamic.string),
      dynamic.field("confirm_password", dynamic.string),
    )

  use body <- api.to_json(request, schema_decoder)

  // there has to be a better way to do this but I'm not sure what it is yet
  let validation_err = case
    body.username,
    body.email,
    body.password,
    body.confirm_password
  {
    "", _, _, _ -> "username is required"
    _, "", _, _ -> "email is required"
    _, _, "", _ -> "password is required"
    _, _, _, "" -> "confirm_password is required"
    _, _, _, _ ->
      case body.password != body.confirm_password {
        True -> "password and confirm_password must match"
        False -> ""
      }
  }

  case validation_err != "" {
    True -> respond.with_err(err: error.ClientError(validation_err), errors: [])
    False -> respond.with_json(message: "sign up", data: None, meta: None)
  }
}

pub fn sign_in(request: api.Request) -> Response(ResponseData) {
  use <- api.require_method(request, Post)
  use <- api.require_json(request)

  respond.with_json(message: "sign in", data: None, meta: None)
}
