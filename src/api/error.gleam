import sqlight
import gleam/http
import lib/logger

pub type JSONError =
  #(Int, String)

pub type ApiError {
  BadRequest
  NotFound
  InternalServerError
  MethodNotAllowed(method: http.Method)
  CustomError(String, Int)
  SqlightError(sqlight.Error)
}

fn make_error(message: String, code: Int) -> JSONError {
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

pub fn get_error(err: ApiError) -> JSONError {
  case err {
    BadRequest -> make_error("Oops, you sent a bad request", 400)
    NotFound -> make_error("The requested resource was not found", 404)
    MethodNotAllowed(method) ->
      make_error(
        "Method " <> method_to_string(method) <> " not allowed for this resource",
        405,
      )
    CustomError(message, code) -> make_error(message, code)
    SqlightError(err) -> {
      // log the error and return a generic error
      logger.error(err.message)
      make_error(err.message, 500)
    }
    _ -> make_error("Internal Server Error", 500)
  }
}
