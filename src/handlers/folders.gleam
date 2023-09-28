import api/api.{Context}
import api/error
import api/respond
import lib/validator
import lib/schemas/folder
import gleam/int
import gleam/dynamic
import gleam/result
import gleam/option.{None, Option, Some}
import gleam/http.{Delete, Get, Patch, Post}
import gleam/http/response.{Response}
import mist.{ResponseData}

type CreateFolderBody {
  CreateFolderBody(name: String, parent_id: Option(Int))
}

pub fn root(ctx: Context) -> Response(ResponseData) {
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

fn create(ctx: Context) -> Response(ResponseData) {
  use <- api.require_method(ctx, Post)
  use uid <- api.require_user(ctx)
  use <- api.require_json(ctx)
  use body <- api.to_json(
    ctx,
    dynamic.decode2(
      CreateFolderBody,
      dynamic.field("name", dynamic.string),
      dynamic.field("parent_id", dynamic.optional(dynamic.int)),
    ),
  )
  use <- api.validate_body([
    validator.Field(
      name: "name",
      value: body.name,
      rules: [
        validator.Required,
        validator.MinLength(1),
        validator.MaxLength(255),
        validator.Regex(
          "^[a-zA-Z0-9_]+$",
          error: "can only contain letters, numbers, and underscores",
        ),
      ],
    ),
    validator.NullableField(
      name: "parent_id",
      value: case body.parent_id {
        Some(id) -> Some(int.to_string(id))
        None -> None
      },
      rules: [validator.Numeric],
    ),
  ])

  case
    folder.create(
      db: ctx.db,
      input: folder.InsertData(
        name: body.name,
        parent_id: body.parent_id,
        user_id: uid,
      ),
    )
  {
    Ok(f) ->
      respond.with_json(
        code: 201,
        message: "Successfully created folder `" <> body.name <> "`",
        data: Some(folder.folder_as_json(f)),
        meta: None,
      )
    Error(err) -> respond.with_err(err: err, errors: [])
  }
}

pub fn id(ctx: Context, folder_id: String) -> Response(ResponseData) {
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

pub fn get_children(ctx: Context, raw_id: String) -> Response(ResponseData) {
  let id =
    int.parse(raw_id)
    |> result.unwrap(0)

  todo
}
