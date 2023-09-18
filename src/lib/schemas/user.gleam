import api/error.{ApiError}
import lib/logger
import gleam/dynamic
import sqlight

pub type User {
  User(
    id: Int,
    username: String,
    email: String,
    created_at: Int,
    updated_at: Int,
  )
}

pub type FindBy {
  Email(String)
  Username(String)
  ID(Int)
}

fn user_decoder() -> dynamic.Decoder(User) {
  dynamic.decode5(
    User,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.string),
    dynamic.element(2, dynamic.string),
    dynamic.element(3, dynamic.int),
    dynamic.element(4, dynamic.int),
  )
}

fn get_find_params(by: FindBy) -> #(String, sqlight.Value) {
  case by {
    Email(email) -> #("email", sqlight.text(email))
    Username(username) -> #("username", sqlight.text(username))
    ID(id) -> #("id", sqlight.int(id))
  }
}

pub fn find_one(
  db db: sqlight.Connection,
  by by: FindBy,
) -> Result(User, ApiError) {
  let #(field, value) = get_find_params(by)
  let query =
    "SELECT id, username, email, created_at, updated_at FROM users WHERE " <> field <> " = $1;"

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
