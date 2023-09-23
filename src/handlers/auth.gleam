import api/api.{Context}
import api/error
import api/respond
import lib/schemas/user
import lib/argon2
import lib/validator.{Email, EqualTo, Field, MaxLength, MinLength, Required}
import gleam/dynamic
import gleam/string
import gleam/http.{Post}
import gleam/http/response.{Response}
import gleam/option.{None, Some}
import mist.{ResponseData}
import sqlight

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

  use <- check_if_user_exists(ctx.db, body.email, body.username, False)

  case
    user.create(
      db: ctx.db,
      input: user.UserInput(
        username: string.trim(body.username),
        email: string.trim(body.email),
        password: argon2.hash_password(body.password),
      ),
    )
  {
    Ok(u) ->
      respond.with_json(
        message: "welcome aboard!",
        data: Some(user.as_json(u)),
        meta: None,
      )
    Error(err) -> respond.with_err(err: err, errors: [])
  }
}

pub fn sign_in(ctx: Context) -> Response(ResponseData) {
  use <- api.require_method(ctx, Post)
  use <- api.require_json(ctx)

  respond.with_json(message: "sign in", data: None, meta: None)
}

type Found {
  Found(by: String)
  NotFound
}

fn check_if_user_exists(
  db: sqlight.Connection,
  email: String,
  username: String,
  // this is used to specify if we expect the user to exist or not when the function is called
  expect: Bool,
  next: fn() -> Response(ResponseData),
) -> Response(ResponseData) {
  let status = case
    user.find_one(db: db, by: user.Email(email)),
    user.find_one(db: db, by: user.Username(username))
  {
    Ok(_), _ -> Found(by: "email")
    _, Ok(_) -> Found(by: "username")
    Error(_), Error(_) -> NotFound
  }

  case status {
    NotFound ->
      case expect {
        True ->
          respond.with_err(err: error.ClientError("user not found"), errors: [])
        False -> next()
      }
    Found(by) ->
      case expect {
        True -> next()
        False ->
          respond.with_err(
            err: error.ClientError(
              "an account with this " <> by <> " already exists",
            ),
            errors: [],
          )
      }
  }
}
