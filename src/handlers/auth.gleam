import api/api.{Context}
import api/error
import api/respond
import lib/argon2
import lib/schemas/user
import lib/token
import lib/validator.{Email, EqualTo, Field, MaxLength, MinLength, Required}
import gleam/dynamic
import gleam/json
import gleam/string
import gleam/http.{Get, Post}
import gleam/http/response.{Response}
import gleam/option.{None, Some}
import mist.{ResponseData}
import sqlight

type SignUpSchema {
  SignUpSchema(
    username: String,
    email: String,
    password: String,
    confirm_password: String,
  )
}

type SignInSchema {
  SignInSchema(identifier: String, password: String)
}

type Found {
  Found(by: String)
  NotFound
}

fn signin_decoder() {
  dynamic.decode2(
    SignInSchema,
    dynamic.field("identifier", dynamic.string),
    dynamic.field("password", dynamic.string),
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
    Field(
      name: "username",
      value: body.username,
      rules: [Required, MinLength(4)],
    ),
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

  use <- ensure_user_doesnt_exist(ctx.db, body.email, body.username)

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
        message: "Account created successfully!",
        data: Some(user.as_json(u)),
        meta: None,
      )
    Error(err) -> respond.with_err(err: err, errors: [])
  }
}

pub fn sign_in(ctx: Context) -> Response(ResponseData) {
  use <- api.require_method(ctx, Post)
  use <- api.require_json(ctx)
  use body <- api.to_json(ctx, signin_decoder())
  use <- api.validate_body([
    Field(
      name: "identifier",
      value: body.identifier,
      rules: [Required, MinLength(4)],
    ),
    Field(
      name: "password",
      value: body.password,
      rules: [Required, MinLength(6), MaxLength(32)],
    ),
  ])

  use user <- match_credentials(
    ctx.db,
    string.trim(body.identifier),
    body.password,
  )

  case token.generate(db: ctx.db, uid: user.id) {
    Ok(tk) ->
      respond.with_json(
        message: "Welcome back, " <> user.username <> "!",
        data: Some(json.object([#("session_token", json.string(tk))])),
        meta: None,
      )
    Error(err) -> respond.with_err(err: err, errors: [])
  }
}

pub fn me(ctx: Context) -> Response(ResponseData) {
  use <- api.require_method(ctx, Get)
  use uid <- api.require_user(ctx)

  case user.find_one(db: ctx.db, by: user.ID(uid)) {
    Ok(u) ->
      respond.with_json(
        message: "Returning current user",
        data: Some(user.as_json(u)),
        meta: None,
      )
    Error(err) -> respond.with_err(err: err, errors: [])
  }
}

fn match_credentials(
  db: sqlight.Connection,
  identifier: String,
  password: String,
  next: fn(user.User) -> Response(ResponseData),
) -> Response(ResponseData) {
  let user =
    user.find_or(
      db: db,
      or: [user.Email(identifier), user.Username(identifier)],
    )

  case user {
    Ok(u) ->
      case argon2.compare_password(password, u.password) {
        True -> next(u)
        False ->
          respond.with_err(
            err: error.ClientError("invalid credentials"),
            errors: [],
          )
      }
    Error(_) ->
      respond.with_err(
        err: error.ClientError("invalid credentials"),
        errors: [],
      )
  }
}

fn ensure_user_doesnt_exist(
  db: sqlight.Connection,
  email: String,
  username: String,
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
    NotFound -> next()
    Found(by) ->
      respond.with_err(
        err: error.ClientError(
          "an account with this " <> by <> " already exists",
        ),
        errors: [],
      )
  }
}
