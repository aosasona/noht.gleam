import api/api.{Context}
import api/error
import api/respond
import gleam/int
import gleam/result
import gleam/option.{None, Option, Some}
import gleam/http.{Delete, Get, Patch, Post}
import gleam/http/response.{Response}
import mist.{ResponseData}

type CreateFolder {
  CreateFolder(name: String, parent_id: Option(Int))
}

pub fn handle_root(ctx: Context) -> Response(ResponseData) {
  case ctx.method {
    Get -> get_all(ctx)
    Post -> create(ctx)
    _ ->
      respond.with_err(
        err: error.MethodNotAllowed(method: ctx.method, path: ctx.path),
        errors: [],
      )
  }
}

pub fn handle_id(ctx: Context, folder_id: String) -> Response(ResponseData) {
  let id = int.parse(folder_id)

  case id {
    Ok(id) ->
      case ctx.method {
        Get -> get_one(ctx, id)
        Patch -> update(ctx, id)
        Delete -> delete(ctx, id)
        _ ->
          respond.with_err(
            err: error.MethodNotAllowed(method: ctx.method, path: ctx.path),
            errors: [],
          )
      }
    Error(_) ->
      respond.with_err(
        err: error.ClientError("Invalid note id, must be an integer"),
        errors: [],
      )
  }
}

fn create(ctx: Context) -> Response(ResponseData) {
  use <- api.require_method(ctx, Post)
  use uid <- api.require_user(ctx)
  use <- api.require_json(ctx)
  todo
}

fn get_all(ctx: Context) -> Response(ResponseData) {
  todo
}

fn get_one(ctx: Context, id: Int) -> Response(ResponseData) {
  todo
}

fn update(ctx: Context, id: Int) -> Response(ResponseData) {
  todo
}

fn delete(ctx: Context, id: Int) -> Response(ResponseData) {
  todo
}

pub fn get_contents(ctx: Context, raw_id: String) -> Response(ResponseData) {
  let id =
    int.parse(raw_id)
    |> result.unwrap(0)

  todo
}

pub fn get_subdirs(ctx: Context, raw_id: String) -> Response(ResponseData) {
  let id =
    int.parse(raw_id)
    |> result.unwrap(0)

  todo
}
