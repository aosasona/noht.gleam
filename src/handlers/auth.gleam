import api/api
import api/error
import api/respond
// import lib/schemas/user.{Email}
import lib/validator.{Email, EqualTo, Field, MaxLength, MinLength, Required}
import gleam/dynamic
import gleam/list
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

  let validation_errors =
    validator.validate_multiple([
      Field(name: "username", value: body.username, rules: [Required]),
      Field(name: "email", value: body.email, rules: [Required, Email]),
      Field(
        name: "password",
        value: body.password,
        rules: [Required, MinLength(8), MaxLength(32)],
      ),
      Field(
        name: "confirm_password",
        value: body.confirm_password,
        rules: [Required, EqualTo(body.password)],
      ),
    ])
    |> validator.to_object

  case list.length(validation_errors) > 0 {
    True ->
      respond.with_err(
        err: error.ClientError("some fields are invalid"),
        errors: validation_errors,
      )
    False -> respond.with_json(message: "sign up", data: None, meta: None)
  }
}

pub fn sign_in(request: api.Request) -> Response(ResponseData) {
  use <- api.require_method(request, Post)
  use <- api.require_json(request)

  respond.with_json(message: "sign in", data: None, meta: None)
}
