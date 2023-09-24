import api/error.{ApiError}
import lib/logger
import gleam/dynamic
import gleam/list
import gleam/string
import gleam/json.{Json}
import gleam/option.{None, Option, Some}
import sqlight

pub type Note {
  Note(
    id: Int,
    title: String,
    body: String,
    folder_id: Option(Int),
    user_id: Int,
    created_at: Int,
    updated_at: Int,
  )
}

pub type Input {
  Input(title: String, body: String, folder_id: Option(Int), user_id: Int)
}

pub type Condition {
  And
  Or
}

pub type Column {
  ID(Int)
  User(uid: Int)
  Folder(fid: Int)
}

fn note_decoder() {
  dynamic.decode7(
    Note,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.string),
    dynamic.element(2, dynamic.string),
    dynamic.element(3, dynamic.optional(dynamic.int)),
    dynamic.element(4, dynamic.int),
    dynamic.element(5, dynamic.int),
    dynamic.element(6, dynamic.int),
  )
}

fn get_find_params(by: Column) -> #(String, sqlight.Value) {
  case by {
    ID(id) -> #("id", sqlight.int(id))
    User(uid) -> #("user_id", sqlight.int(uid))
    Folder(fid) -> #("folder_id", sqlight.int(fid))
  }
}

fn make_where_clause(
  condition: Condition,
  columns: List(Column),
) -> #(String, List(sqlight.Value)) {
  let cond = case condition {
    And -> "AND"
    Or -> "OR"
  }

  let fields =
    columns
    |> list.map(fn(col) -> String {
      let #(name, _) = get_find_params(col)
      name
    })
    |> string.join(with: " = ? " <> cond <> " ")

  let values =
    columns
    |> list.map(fn(col) -> sqlight.Value {
      let #(_, value) = get_find_params(col)
      value
    })

  #(fields <> " = ?", values)
}

pub fn find_one(
  db db: sqlight.Connection,
  by by: Column,
  condition condition: Condition,
) -> Result(Option(Note), ApiError) {
  let #(where, values) = make_where_clause(condition, [by])
  let query =
    "SELECT id, title, body, folder_id, user_id, UNIXEPOCH(created_at), UNIXEPOCH(updated_at) FROM notes WHERE " <> where <> " LIMIT 1;"

  let rows =
    sqlight.query(query, on: db, with: values, expecting: note_decoder())

  case rows {
    Ok([row]) -> Ok(Some(row))
    Ok(_) -> Ok(None)
    Error(e) -> {
      logger.error(e.message)
      Error(error.InternalServerError)
    }
  }
}

pub fn find_many(
  db db: sqlight.Connection,
  by by: List(Column),
  condition condition: Condition,
) -> Result(List(Note), ApiError) {
  let #(where, values) = make_where_clause(condition, by)
  let query =
    "SELECT id, title, body, folder_id, user_id, UNIXEPOCH(created_at), UNIXEPOCH(updated_at) FROM notes WHERE " <> where <> ";"

  let rows =
    sqlight.query(query, on: db, with: values, expecting: note_decoder())

  case rows {
    Ok(rows) -> Ok(rows)
    Error(e) -> {
      logger.error(e.message)
      Error(error.InternalServerError)
    }
  }
}

pub fn create(
  db db: sqlight.Connection,
  input input: Input,
) -> Result(Note, ApiError) {
  let query =
    "INSERT INTO notes (title, body, folder_id, user_id) VALUES (?, ?, ?, ?) RETURNING id, title, body, folder_id, user_id, UNIXEPOCH(created_at), UNIXEPOCH(updated_at)"
  let params = [
    sqlight.text(input.title),
    sqlight.text(input.body),
    case input.folder_id {
      Some(fid) -> sqlight.int(fid)
      None -> sqlight.null()
    },
    sqlight.int(input.user_id),
  ]

  let rows =
    sqlight.query(query, on: db, with: params, expecting: note_decoder())

  case rows {
    Ok([row]) -> Ok(row)
    Ok(_) -> Error(error.CustomError("Failed to create note", 500))
    Error(e) -> {
      logger.error(e.message)
      Error(error.InternalServerError)
    }
  }
}

pub fn as_json(note: Note) -> Json {
  json.object([
    #("id", json.int(note.id)),
    #("title", json.string(note.title)),
    #("body", json.string(note.body)),
    #(
      "folder_id",
      case note.folder_id {
        Some(f_id) -> json.int(f_id)
        None -> json.null()
      },
    ),
    #("user_id", json.int(note.user_id)),
    #("created_at", json.int(note.created_at)),
    #("updated_at", json.int(note.updated_at)),
  ])
}
