import gleam/http

pub type AppRequest {
  AppRequest(
    method: http.Method,
    path: List(String),
    headers: List(#(String, String)),
    body: String,
    db: String,
    user_id: Int,
  )
}
