import sqlight
import gleam/http
import gleam/string
import lib/logger

pub type HTTPError =
  #(Int, String)

pub type ApiError {
  BadRequest
  BadAuthToken
  Forbidden
  Unauthenticated
  UnprocessableEntity
  NotFound
  InternalServerError
  MethodNotAllowed(method: http.Method, path: List(String))
  ClientError(message: String)
  InvalidContentType(provided: String, expected: String)
  CustomError(String, Int)
  SqlightError(sqlight.Error)
}

fn make_error(message: String, code: Int) -> HTTPError {
  #(code, message)
}

fn method_to_string(method: http.Method) -> String {
  case method {
    http.Get -> "GET"
    http.Post -> "POST"
    http.Put -> "PUT"
    http.Delete -> "DELETE"
    http.Patch -> "PATCH"
    http.Options -> "OPTIONS"
    http.Head -> "HEAD"
    http.Connect -> "CONNECT"
    http.Trace -> "TRACE"
    http.Other(method) -> method
  }
}

pub fn get_error(err: ApiError) -> HTTPError {
  case err {
    BadRequest -> make_error("Oops, you sent a bad request", 400)
    BadAuthToken | Unauthenticated ->
      make_error("You need to be logged in to do that", 401)
    ClientError(message) -> make_error(message, 400)
    CustomError(message, code) -> make_error(message, code)
    Forbidden -> make_error("You don't have permission to do that", 403)
    InvalidContentType(provided, expected) -> {
      let message =
        "Invalid Content-Type header. Expected " <> expected <> ", got " <> provided
      make_error(message, 415)
    }
    NotFound -> make_error("The requested resource was not found", 404)
    MethodNotAllowed(method, path_parts) -> {
      let path = string.join(path_parts, "/")
      make_error("Cannot " <> method_to_string(method) <> " /" <> path, 405)
    }
    SqlightError(err) -> {
      // log the error and return a generic error
      logger.error(err.message)
      make_error(err.message, 500)
    }
    UnprocessableEntity -> make_error("Unprocessable Entity", 422)
    _ -> make_error("Internal Server Error", 500)
  }
}
