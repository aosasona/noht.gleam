import api/error.{ApiError}
import lib/logger
import gleam/int
import gleam/json.{Json}
import gleam/list
import gleam/dynamic
import sqlight

pub type User {
  User(
    id: Int,
    username: String,
    email: String,
    password: String,
    created_at: Int,
    updated_at: Int,
  )
}

pub type UserInput {
  UserInput(username: String, email: String, password: String)
}

pub type FindBy {
  Email(String)
  Username(String)
  ID(Int)
}

fn user_decoder() -> dynamic.Decoder(User) {
  dynamic.decode6(
    User,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.string),
    dynamic.element(2, dynamic.string),
    dynamic.element(3, dynamic.string),
    dynamic.element(4, dynamic.int),
    dynamic.element(5, dynamic.int),
  )
}

fn get_find_params(by: FindBy) -> #(String, sqlight.Value) {
  case by {
    Email(email) -> #("email", sqlight.text(email))
    Username(username) -> #("username", sqlight.text(username))
    ID(id) -> #("id", sqlight.int(id))
  }
}

pub fn create(
  db db: sqlight.Connection,
  input input: UserInput,
) -> Result(User, ApiError) {
  let query =
    "INSERT INTO users (username, email, password) VALUES ($1, $2, $3) RETURNING id, username, email, password, UNIXEPOCH(created_at), UNIXEPOCH(updated_at);"

  let rows =
    sqlight.query(
      query,
      on: db,
      with: [
        sqlight.text(input.username),
        sqlight.text(input.email),
        sqlight.text(input.password),
      ],
      expecting: user_decoder(),
    )

  case rows {
    Ok([user]) -> Ok(user)
    Ok([_, ..rest]) -> {
      logger.error(
        "Expected 1 row, got " <> int.to_string(list.length(rest) + 1),
      )
      Error(error.InternalServerError)
    }
    Error(error) -> {
      logger.error(error.message)
      Error(error.InternalServerError)
    }
  }
}

pub fn find_one(
  db db: sqlight.Connection,
  by by: FindBy,
) -> Result(User, ApiError) {
  let #(field, value) = get_find_params(by)
  let query =
    "SELECT id, username, email, password, UNIXEPOCH(created_at), UNIXEPOCH(updated_at) FROM users WHERE " <> field <> " = $1;"

  let rows =
    sqlight.query(query, on: db, with: [value], expecting: user_decoder())

  case rows {
    Ok([user]) -> Ok(user)
    Ok(_) -> Error(error.ClientError("No account found with that" <> field))
    Error(error) -> {
      logger.error(error.message)
      Error(error.InternalServerError)
    }
  }
}

pub fn as_json(user: User) -> Json {
  json.object([
    #("id", json.int(user.id)),
    #("username", json.string(user.username)),
    #("email", json.string(user.email)),
    #("created_at", json.int(user.created_at)),
    #("updated_at", json.int(user.updated_at)),
  ])
}
