import api/api.{Context}
import api/error
import api/respond
import lib/schemas/note
import lib/database.{And}
import lib/validator
import gleam/int
import gleam/json
import gleam/dynamic
import gleam/option.{None, Option, Some}
import gleam/http.{Delete, Get, Patch, Post}
import gleam/http/response.{Response}
import mist.{ResponseData}

type CreateNoteBody {
  CreateNoteBody(title: String, body: String, folder_id: Option(Int))
}

type UpdateNoteBody {
  UpdateNoteBody(
    title: Option(String),
    body: Option(String),
    folder_id: Option(Int),
  )
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

pub fn id(ctx: Context, note_id: String) -> Response(ResponseData) {
  let id = int.parse(note_id)

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
    dynamic.decode3(
      CreateNoteBody,
      dynamic.field("title", dynamic.string),
      dynamic.field("body", dynamic.string),
      dynamic.field("folder_id", dynamic.optional(dynamic.int)),
    ),
  )

  use <- api.validate_body([
    validator.Field(
      name: "title",
      value: body.title,
      rules: [
        validator.Required,
        validator.MinLength(1),
        validator.MaxLength(255),
        validator.Filename,
      ],
    ),
    validator.Field(
      name: "body",
      value: body.body,
      rules: [validator.MaxLength(65_535)],
    ),
  ])

  note.create(
    db: ctx.db,
    input: note.InsertData(
      title: body.title,
      body: body.body,
      folder_id: body.folder_id,
      user_id: uid,
    ),
  )
  |> fn(res) {
    case res {
      Ok(n) ->
        respond.with_json(
          code: 201,
          message: "Note created!",
          data: Some(note.as_json(n)),
          meta: None,
        )
      Error(err) -> respond.with_err(err: err, errors: [])
    }
  }
}

fn get_all(ctx: Context) -> Response(ResponseData) {
  use <- api.require_method(ctx, Get)
  use uid <- api.require_user(ctx)

  case note.find_many(db: ctx.db, where: [note.UserID(uid)], condition: And) {
    Ok(notes) ->
      respond.with_json(
        code: 200,
        message: "Notes found!",
        data: Some(
          notes
          |> json.array(of: note.as_json),
        ),
        meta: None,
      )
    Error(err) -> respond.with_err(err: err, errors: [])
  }
}

pub fn get_one(ctx: Context, note_id: Int) -> Response(ResponseData) {
  use <- api.require_method(ctx, Get)
  use uid <- api.require_user(ctx)

  case
    note.find_one(
      db: ctx.db,
      where: [note.ID(note_id), note.UserID(uid)],
      condition: And,
    )
  {
    Ok(res) -> {
      let #(d, code) = case res {
        Some(d) -> #(note.as_json(d), 200)
        None -> #(json.null(), 400)
      }
      respond.with_json(
        code: code,
        message: case code {
          200 -> "Returning data for note with ID " <> int.to_string(note_id)
          _ -> "Note with ID " <> int.to_string(note_id) <> " not found"
        },
        data: Some(d),
        meta: None,
      )
    }
    Error(err) -> respond.with_err(err: err, errors: [])
  }
}

pub fn delete(ctx: Context, note_id: Int) -> Response(ResponseData) {
  use <- api.require_method(ctx, Delete)
  use uid <- api.require_user(ctx)
  let exists = case
    note.find_one(
      db: ctx.db,
      where: [note.ID(note_id), note.UserID(uid)],
      condition: And,
    )
  {
    Ok(res) ->
      case res {
        Some(_) -> True
        None -> False
      }
    Error(_) -> False
  }

  use <- fn(exists: Bool, next: fn() -> Response(ResponseData)) {
    case exists {
      True -> next()
      False ->
        respond.with_err(
          err: error.ClientError("This note does not exist!"),
          errors: [],
        )
    }
  }(exists)

  case
    note.delete(
      db: ctx.db,
      where: [note.ID(note_id), note.UserID(uid)],
      condition: And,
    )
  {
    Ok(nid) ->
      respond.with_json(
        code: 200,
        message: "Note deleted!",
        data: Some(json.object([#("id", json.int(nid))])),
        meta: None,
      )
    Error(err) -> respond.with_err(err: err, errors: [])
  }
}

pub fn update(ctx: Context, note_id: Int) -> Response(ResponseData) {
  use <- api.require_method(ctx, Patch)
  use uid <- api.require_user(ctx)
  use <- api.require_json(ctx)
  validator.Numeric
  use body <- api.to_json(
    ctx,
    dynamic.decode3(
      UpdateNoteBody,
      dynamic.field("title", dynamic.optional(dynamic.string)),
      dynamic.field("body", dynamic.optional(dynamic.string)),
      dynamic.field("folder_id", dynamic.optional(dynamic.int)),
    ),
  )

  use <- api.validate_body([
    validator.NullableField(
      name: "title",
      value: body.title,
      rules: [
        validator.Required,
        validator.MinLength(1),
        validator.MaxLength(255),
        validator.Filename,
      ],
    ),
    validator.NullableField(
      name: "body",
      value: body.body,
      rules: [validator.MaxLength(65_535)],
    ),
    validator.NullableField(
      name: "folder_id",
      value: case body.folder_id {
        Some(fid) -> Some(int.to_string(fid))
        None -> None
      },
      rules: [validator.Numeric],
    ),
  ])

  case
    note.update(
      db: ctx.db,
      data: note.UpdateData(
        body: body.body,
        title: body.title,
        folder_id: body.folder_id,
      ),
      where: [note.ID(note_id), note.UserID(uid)],
      condition: And,
    )
  {
    Ok(#(updated_note, fields)) ->
      respond.with_json(
        code: 200,
        message: "Note updated!",
        data: Some(note.as_json(updated_note)),
        meta: Some(json.object([
          #("fields", json.array(from: fields, of: json.string)),
        ])),
      )
    Error(e) -> respond.with_err(err: e, errors: [])
  }
}
