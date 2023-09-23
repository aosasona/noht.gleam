import api/error.{ApiError}
import lib/logger
import sqlight
import gleam/int
import gleam/list
import gleam/result
import gleam/dynamic

pub type Token {
  Token(id: Int, user_id: Int, token: String, issued_at: Int, last_used_at: Int)
}

fn token_decoder() -> dynamic.Decoder(Token) {
  dynamic.decode5(
    Token,
    dynamic.field(0, dynamic.int),
    dynamic.field(1, dynamic.int),
    dynamic.field(2, dynamic.string),
    dynamic.field(3, dynamic.int),
    dynamic.field(4, dynamic.int),
  )
}

pub fn save(
  conn: sqlight.Connection,
  user_id user_id: Int,
  token token: String,
) -> Result(String, ApiError) {
  let query =
    "INSERT INTO _auth_tokens (user_id, token) VALUES ($1, $2) RETURNING token;"

  let rows =
    sqlight.query(
      query,
      on: conn,
      with: [sqlight.int(user_id), sqlight.text(token)],
      expecting: dynamic.element(0, dynamic.string),
    )
    |> result.map_error(fn(error) {
      case error.code {
        sqlight.ConstraintForeignkey -> error.CustomError("User not found", 404)
        _ -> {
          logger.error(error.message)
          error.InternalServerError
        }
      }
    })

  case rows {
    Ok([row]) -> Ok(row)
    Ok([_, ..rest]) -> {
      logger.error(
        "Expected 1 row, got " <> int.to_string(list.length(rest) + 1),
      )
      Error(error.InternalServerError)
    }
    Error(error) -> Error(error)
  }
}

pub fn find_by_value(
  db db: sqlight.Connection,
  token token: String,
) -> Result(Token, ApiError) {
  // A token is only considered valid if it was issued in the last 14 days, and has been used in the last 3 days
  // This is not really secure, you want to use something more strict in a real app
  let query =
    "SELECT
      id, user_id, token, issued_at, last_used_at
    FROM _auth_tokens
    WHERE
      token = $1
      AND issued_at >= strftime('%s', 'now', '-14 days')
      AND last_used_at <= strftime('%s', 'now', '-3 days');
    "

  let rows =
    sqlight.query(
      query,
      on: db,
      with: [sqlight.text(token)],
      expecting: token_decoder(),
    )

  case rows {
    Ok([user]) -> Ok(user)
    Ok(_) -> Error(error.BadAuthToken)
    Error(error) -> {
      logger.error(error.message)
      Error(error.InternalServerError)
    }
  }
}

pub fn update_last_used_at(
  db db: sqlight.Connection,
  token token: String,
) -> Result(Nil, ApiError) {
  let query =
    "UPDATE _auth_tokens SET last_used_at = CURRENT_TIMESTAMP WHERE token = $1 RETURNING id;"

  let rows =
    sqlight.query(
      query,
      on: db,
      with: [sqlight.text(token)],
      expecting: dynamic.element(0, dynamic.int),
    )

  case rows {
    Ok(_) -> Ok(Nil)
    Error(error) -> {
      logger.error(
        "Failed to update last_used_at for token: " <> token <> ", error: " <> error.message,
      )
      Error(error.InternalServerError)
    }
  }
}
