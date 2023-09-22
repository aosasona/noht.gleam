import api/api.{Context}
import api/error
import api/respond
import lib/schemas/user
import lib/validator.{Email, EqualTo, Field, MaxLength, MinLength, Required}
import gleam/dynamic
import gleam/http.{Post}
import gleam/http/response.{Response}
import gleam/option.{None}
import mist.{ResponseData}

type BodySchema {
  SignUpSchema(
    username: String,
    email: String,
    password: String,
    confirm_password: String,
  )
}

fn signup_decoder() {
  dynamic.decode4(
    SignUpSchema,
    dynamic.field("username", dynamic.string),
    dynamic.field("email", dynamic.string),
    dynamic.field("password", dynamic.string),
    dynamic.field("confirm_password", dynamic.string),
  )
}

pub fn sign_up(ctx: Context) -> Response(ResponseData) {
  use <- api.require_method(ctx, Post)
  use <- api.require_json(ctx)
  use body <- api.to_json(ctx, signup_decoder())

  use <- api.validate_body([
    Field(name: "username", value: body.username, rules: [Required]),
    Field(name: "email", value: body.email, rules: [Required, Email]),
    Field(
      name: "password",
      value: body.password,
      rules: [Required, MinLength(6), MaxLength(32)],
    ),
    Field(
      name: "confirm_password",
      value: body.confirm_password,
      rules: [Required, EqualTo(name: "password", value: body.password)],
    ),
  ])

  respond.with_json(message: "sign up", data: None, meta: None)
}

pub fn sign_in(ctx: Context) -> Response(ResponseData) {
  use <- api.require_method(ctx, Post)
  use <- api.require_json(ctx)

  respond.with_json(message: "sign in", data: None, meta: None)
}
