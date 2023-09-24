import api/api.{Context}
import api/error
import api/respond
import gleam/int
import gleam/http.{Delete, Get, Patch, Post}
import gleam/http/response.{Response}
import mist.{ResponseData}

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

pub fn handle_id(ctx: Context, note_id: String) -> Response(ResponseData) {
  let id = int.parse(note_id)

  case id {
    Ok(id) ->
      case ctx.method {
        Get -> get_note(ctx, id)
        Patch -> edit_note(ctx, id)
        Delete -> delete_note(ctx, id)
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
  todo
}

fn get_all(ctx: Context) -> Response(ResponseData) {
  todo
}

pub fn get_note(ctx: Context, note_id: Int) -> Response(ResponseData) {
  todo
}

pub fn edit_note(ctx: Context, note_id: Int) -> Response(ResponseData) {
  todo
}

pub fn delete_note(ctx: Context, note_id: Int) -> Response(ResponseData) {
  todo
}