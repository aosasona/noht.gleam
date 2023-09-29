import api/api.{Context}
import api/error
import api/respond
import lib/validator
import lib/schemas/folder
import lib/schemas/note
import lib/database.{And}
import gleam/int
import gleam/list
import gleam/result
import gleam/dynamic
import gleam/json
import gleam/option.{None, Option, Some}
import gleam/http.{Delete, Get, Patch, Post}
import gleam/http/response.{Response}
import gleam/http/request
import mist.{ResponseData}

type CreateFolderBody {
  CreateFolderBody(name: String, parent_id: Option(Int))
}

type UpdateNoteBody {
  UpdateNoteBody(name: Option(String), parent_id: Option(Int))
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
        validator.Filename,
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
        data: Some(folder.as_json(f)),
        meta: None,
      )
    Error(err) -> respond.with_err(err: err, errors: [])
  }
}

fn get_all(ctx: Context) -> Response(ResponseData) {
  use <- api.require_method(ctx, Get)
  use uid <- api.require_user(ctx)

  case
    folder.find_many(
      db: ctx.db,
      where: [folder.UserID(uid), folder.ParentID(None)],
      condition: And,
    )
  {
    Ok(folders) ->
      respond.with_json(
        code: 200,
        message: "Successfully retrieved folders",
        data: Some(
          folders
          |> json.array(of: folder.as_json),
        ),
        meta: None,
      )
    Error(e) -> respond.with_err(err: e, errors: [])
  }
}

fn get_one(ctx: Context, folder_id: Int) -> Response(ResponseData) {
  use <- api.require_method(ctx, Get)
  use uid <- api.require_user(ctx)

  case
    folder.find_one(
      db: ctx.db,
      where: [folder.UserID(uid), folder.ID(folder_id)],
      condition: And,
    )
  {
    Ok(res) -> {
      case res {
        Some(data) ->
          respond.with_json(
            code: 200,
            message: "Successfully retrieved folders",
            data: Some(folder.as_json(data)),
            meta: None,
          )
        None ->
          respond.with_err(
            err: error.ClientError("Folder not found"),
            errors: [],
          )
      }
    }
    Error(e) -> respond.with_err(err: e, errors: [])
  }
}

pub fn get_content(ctx: Context, str_id: String) -> Response(ResponseData) {
  use <- api.require_method(ctx, Get)
  use uid <- api.require_user(ctx)
  use folder_id <- fn(raw_id: String, next: fn(Int) -> Response(ResponseData)) {
    case int.parse(raw_id) {
      Ok(id) -> next(id)
      Error(_) ->
        respond.with_err(
          err: error.ClientError("Invalid folder id, must be an integer"),
          errors: [],
        )
    }
  }(str_id)

  let format = case request.get_query(ctx.original_request) {
    Ok(queries) -> {
      queries
      |> list.key_find(find: "format")
      |> result.unwrap(or: "")
    }

    Error(_) -> ""
  }

  let subfolders = case
    folder.find_many(
      db: ctx.db,
      where: [folder.ParentID(Some(folder_id)), folder.UserID(uid)],
      condition: And,
    )
  {
    Ok(d) -> d
    Error(_) -> []
  }

  let notes = case
    note.find_many(
      db: ctx.db,
      where: [note.FolderID(folder_id), note.UserID(uid)],
      condition: And,
    )
  {
    Ok(d) -> d
    Error(_) -> []
  }

  respond.with_json(
    code: 200,
    message: "Successfully retrieved folder content",
    data: Some(case format {
      "mixed" ->
        json.array(
          from: list.append(
            subfolders
            |> list.map(fn(f) { folder.SubFolder(f) }),
            notes
            |> list.map(fn(n) { folder.Note(n) }),
          ),
          of: folder.child_as_json,
        )
      _ ->
        json.object([
          #("subfolders", json.array(from: subfolders, of: folder.as_json)),
          #("notes", json.array(from: notes, of: note.as_json)),
        ])
    }),
    meta: None,
  )
}

fn update(ctx: Context, folder_id: Int) -> Response(ResponseData) {
  use <- api.require_method(ctx, Patch)
  use uid <- api.require_user(ctx)
  use <- api.require_json(ctx)
  validator.Numeric
  use body <- api.to_json(
    ctx,
    dynamic.decode2(
      UpdateNoteBody,
      dynamic.field("name", dynamic.optional(dynamic.string)),
      dynamic.field("parent_id", dynamic.optional(dynamic.int)),
    ),
  )

  use <- api.validate_body([
    validator.NullableField(
      name: "name",
      value: body.name,
      rules: [
        validator.Required,
        validator.MinLength(1),
        validator.MaxLength(255),
        validator.Filename,
      ],
    ),
    validator.NullableField(
      name: "parent_id",
      value: case body.parent_id {
        Some(fid) -> Some(int.to_string(fid))
        None -> None
      },
      rules: [validator.Numeric],
    ),
  ])

  case
    folder.update(
      db: ctx.db,
      data: folder.UpdateData(name: body.name, parent_id: body.parent_id),
      where: [folder.ID(folder_id), folder.UserID(uid)],
      condition: And,
    )
  {
    Ok(#(updated_folder, fields)) ->
      respond.with_json(
        code: 200,
        message: "Note updated!",
        data: Some(folder.as_json(updated_folder)),
        meta: Some(json.object([
          #("fields", json.array(from: fields, of: json.string)),
        ])),
      )
    Error(e) -> respond.with_err(err: e, errors: [])
  }
}

fn delete(ctx: Context, folder_id: Int) -> Response(ResponseData) {
  use <- api.require_method(ctx, Delete)
  use uid <- api.require_user(ctx)

  use <- fn(exists: Bool, next: fn() -> Response(ResponseData)) {
    case exists {
      True -> next()
      False ->
        respond.with_err(err: error.ClientError("Folder not found"), errors: [])
    }
  }(database.exists(folder.find_one(
    db: ctx.db,
    where: [folder.ID(folder_id), folder.UserID(uid)],
    condition: And,
  )))

  case
    folder.delete(
      db: ctx.db,
      where: [folder.ID(folder_id), folder.UserID(uid)],
      condition: And,
    )
  {
    Ok(_) ->
      respond.with_json(
        code: 200,
        message: "Successfully deleted folder",
        data: Some(json.object([#("id", json.int(folder_id))])),
        meta: None,
      )
    Error(e) -> respond.with_err(err: e, errors: [])
  }
}
