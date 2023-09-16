import gleam/http
import gleam/option.{Option}
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

pub type User {
  User(id: Int, email: String, password_hash: String)
}
