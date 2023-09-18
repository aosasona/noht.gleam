import api/api
import api/respond
// import lib/schemas/user.{Email}
import gleam/http.{Post}
import gleam/http/response.{Response}
import gleam/option.{None}
import mist.{ResponseData}

pub fn sign_up(request: api.Request) -> Response(ResponseData) {
  use <- api.require_method(request, Post)

  respond.with_json(message: "sign up", data: None, meta: None)
}

pub fn sign_in(request: api.Request) -> Response(ResponseData) {
  use <- api.require_method(request, Post)

  respond.with_json(message: "sign in", data: None, meta: None)
}
