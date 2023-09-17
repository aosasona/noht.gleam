pub type JSONError =
  #(Int, String)

pub type ApiError {
  BadRequest
  NotFound
  InternalServerError
  CustomError(String, Int)
}

fn make_error(message: String, code: Int) -> JSONError {
  #(code, message)
}

pub fn get_error(err: ApiError) -> JSONError {
  case err {
    BadRequest -> make_error("Oops, you sent a bad request", 400)
    NotFound -> make_error("The requested resource was not found", 404)
    CustomError(message, code) -> make_error(message, code)
    _ -> make_error("Internal Server Error", 500)
  }
}
