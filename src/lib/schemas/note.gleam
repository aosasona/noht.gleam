import api/error.{ApiError}
import lib/logger
import lib/database.{And, Condition, Or}
import gleam/dynamic
import gleam/list
import gleam/map
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

pub type InsertData {
  InsertData(title: String, body: String, folder_id: Option(Int), user_id: Int)
}

pub type UpdateData {
  UpdateData(
    title: Option(String),
    body: Option(String),
    folder_id: Option(Int),
  )
}

pub type Column {
  ID(Int)
  UserID(uid: Int)
  FolderID(fid: Int)
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
    UserID(uid) -> #("user_id", sqlight.int(uid))
    FolderID(fid) -> #("folder_id", sqlight.int(fid))
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
  where by: List(Column),
  condition condition: Condition,
) -> Result(Option(Note), ApiError) {
  let #(where, values) = make_where_clause(condition, by)

  let query =
    "SELECT id, title, body, folder_id, user_id, UNIXEPOCH(created_at), UNIXEPOCH(updated_at) FROM notes WHERE " <> where <> " LIMIT 1;"
  logger.info(query)

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
  where by: List(Column),
  condition condition: Condition,
) -> Result(List(Note), ApiError) {
  let #(where, values) = make_where_clause(condition, by)

  let query =
    "SELECT id, title, body, folder_id, user_id, UNIXEPOCH(created_at), UNIXEPOCH(updated_at) FROM notes WHERE " <> where <> " ORDER BY title, body ASC;"
  logger.info(query)

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
  input input: InsertData,
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
    Ok(_) -> Error(error.InternalServerError)
    Error(e) -> {
      logger.error(e.message)
      case e.code {
        sqlight.ConstraintForeignkey | sqlight.ConstraintCheck ->
          Error(error.ClientError("The target folder does not exist"))
        _ -> Error(error.InternalServerError)
      }
    }
  }
}

pub fn delete(
  db db: sqlight.Connection,
  where by: List(Column),
  condition condition: Condition,
) -> Result(Int, ApiError) {
  let #(where, values) = make_where_clause(condition, by)

  let query = "DELETE FROM notes WHERE " <> where <> " RETURNING id;"
  logger.info(query)

  let rows =
    sqlight.query(
      query,
      on: db,
      with: values,
      expecting: dynamic.element(0, dynamic.int),
    )

  case rows {
    Ok([row]) -> Ok(row)
    Ok(_) -> Error(error.ClientError("Note not found"))
    Error(e) -> {
      logger.error(e.message)
      Error(error.InternalServerError)
    }
  }
}

pub fn update(
  db db: sqlight.Connection,
  data data: UpdateData,
  where by: List(Column),
  condition condition: Condition,
) -> Result(#(Note, List(String)), ApiError) {
  let new_data =
    [#("title", data.title), #("body", data.body)]
    |> list.filter(for: fn(field) -> Bool {
      case field {
        #(_, Some(_)) -> True
        #(_, None) -> False
      }
    })
    |> list.map(fn(field) -> #(String, sqlight.Value) {
      case field {
        #(name, Some(value)) -> #(name, sqlight.text(value))
        // this will never happen anyway since we have filtered out None values
        #(_, None) -> #("", sqlight.null())
      }
    })
    |> fn(fields) -> List(#(String, sqlight.Value)) {
      case data.folder_id {
        Some(fid) -> list.append(fields, [#("folder_id", sqlight.int(fid))])
        None -> fields
      }
    }
    |> map.from_list

  let #(fields, set_values) = #(map.keys(new_data), map.values(new_data))
  let #(where, where_values) = make_where_clause(condition, by)

  let query =
    "UPDATE notes SET " <> string.join(fields, with: " = ?, ") <> " = ?, updated_at = CURRENT_TIMESTAMP WHERE " <> where <> " RETURNING id, title, body, folder_id, user_id, UNIXEPOCH(created_at), UNIXEPOCH(updated_at);"

  logger.info(query)

  case list.length(fields) > 0 {
    True -> {
      case
        sqlight.query(
          query,
          on: db,
          with: list.append(set_values, where_values),
          expecting: note_decoder(),
        )
      {
        Ok([row]) -> Ok(#(row, fields))
        Ok(_) -> Error(error.InternalServerError)
        Error(e) -> {
          logger.error(e.message)
          case e.code {
            sqlight.ConstraintForeignkey ->
              Error(error.ClientError("The target folder does not exist"))
            _ -> Error(error.InternalServerError)
          }
        }
      }
    }
    False -> Error(error.CustomError("No fields to update", 400))
  }
}

pub fn as_json(note: Note) -> Json {
  json.object([
    #("id", json.int(note.id)),
    #("title", json.string(note.title)),
    #("body", json.string(note.body)),
    #("user_id", json.int(note.user_id)),
    #("folder_id", json.nullable(from: note.folder_id, of: json.int)),
    #("created_at", json.int(note.created_at)),
    #("updated_at", json.int(note.updated_at)),
  ])
}
