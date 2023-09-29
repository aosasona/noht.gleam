import api/error.{ApiError}
import lib/database.{And, Condition, Or}
import lib/schemas/note.{Note}
import lib/logger
import gleam/string
import gleam/list
import gleam/dynamic
import gleam/option.{None, Option, Some}
import gleam/json.{Json}
import gleam/map
import sqlight

pub type Folder {
  Folder(
    id: Int,
    name: String,
    user_id: Int,
    parent_id: Option(Int),
    created_at: Int,
    updated_at: Int,
  )
}

pub type Child {
  SubFolder(Folder)
  Note(Note)
}

pub type Column {
  ID(Int)
  UserID(uid: Int)
  ParentID(parent_id: Option(Int))
}

pub type InsertData {
  InsertData(name: String, parent_id: Option(Int), user_id: Int)
}

pub type UpdateData {
  UpdateData(name: Option(String), parent_id: Option(Int))
}

fn folder_decoder() {
  dynamic.decode6(
    Folder,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.string),
    dynamic.element(2, dynamic.int),
    dynamic.element(3, dynamic.optional(dynamic.int)),
    dynamic.element(4, dynamic.int),
    dynamic.element(5, dynamic.int),
  )
}

fn get_find_params(by: Column) -> #(String, sqlight.Value) {
  case by {
    ID(id) -> #("id", sqlight.int(id))
    UserID(uid) -> #("user_id", sqlight.int(uid))
    ParentID(parent_id) -> #(
      "parent_id",
      sqlight.nullable(sqlight.int, parent_id),
    )
  }
}

// in a real app, this would probably be an exported function instead of a copy-pasta
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
    |> list.map(fn(col) {
      let #(col, v) = get_find_params(col)
      col <> case v == sqlight.null() {
        True -> " IS NULL"
        False -> " = ?"
      }
    })
    |> string.join(with: " " <> cond <> " ")

  let values =
    columns
    |> list.filter(fn(col) {
      let #(_, value) = get_find_params(col)
      value != sqlight.null()
    })
    |> list.map(fn(col) -> sqlight.Value {
      let #(_, value) = get_find_params(col)
      value
    })

  #(fields, values)
}

pub fn create(
  db db: sqlight.Connection,
  input input: InsertData,
) -> Result(Folder, ApiError) {
  let query =
    "INSERT INTO folders (name, user_id, parent_id) VALUES(?, ?, ?) RETURNING id, name, user_id, parent_id, UNIXEPOCH(created_at), UNIXEPOCH(updated_at)"
  let params = [
    sqlight.text(input.name),
    sqlight.int(input.user_id),
    sqlight.nullable(sqlight.int, input.parent_id),
  ]

  let rows =
    sqlight.query(query, on: db, with: params, expecting: folder_decoder())

  case rows {
    Ok([row]) -> Ok(row)
    Ok(_) -> Error(error.InternalServerError)
    Error(e) -> {
      logger.error(e.message)
      case e.code {
        sqlight.ConstraintUnique ->
          Error(error.ClientError("A folder with that name already exists"))
        sqlight.ConstraintForeignkey | sqlight.ConstraintCheck ->
          Error(error.ClientError("The parent folder does not exist"))
        _ -> Error(error.InternalServerError)
      }
    }
  }
}

pub fn find_one(
  db db: sqlight.Connection,
  where by: List(Column),
  condition condition: Condition,
) -> Result(Option(Folder), ApiError) {
  let #(where, values) = make_where_clause(condition, by)

  let query =
    "SELECT id, name, user_id, parent_id, UNIXEPOCH(created_at), UNIXEPOCH(updated_at) FROM folders WHERE " <> where <> " LIMIT 1;"
  logger.info(query)

  let rows =
    sqlight.query(query, on: db, with: values, expecting: folder_decoder())

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
) -> Result(List(Folder), ApiError) {
  let #(where, values) = make_where_clause(condition, by)

  let query =
    "SELECT id, name, user_id, parent_id, UNIXEPOCH(created_at), UNIXEPOCH(updated_at) FROM folders WHERE " <> where <> " ORDER BY name ASC;"
  logger.info(query)

  let rows =
    sqlight.query(query, on: db, with: values, expecting: folder_decoder())

  case rows {
    Ok(rows) -> Ok(rows)
    Error(e) -> {
      logger.error(e.message)
      Error(error.InternalServerError)
    }
  }
}

pub fn delete(
  db db: sqlight.Connection,
  where by: List(Column),
  condition condition: Condition,
) -> Result(Int, ApiError) {
  let #(where, values) = make_where_clause(condition, by)

  let query = "DELETE FROM folders WHERE " <> where <> " RETURNING id;"
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
    Ok(_) -> Error(error.ClientError("Folder not found"))
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
) -> Result(#(Folder, List(String)), ApiError) {
  let new_data =
    []
    |> fn(d) -> List(#(String, sqlight.Value)) {
      case data.name {
        Some(name) -> [#("name", sqlight.text(name))]
        None -> d
      }
    }
    |> fn(d) -> List(#(String, sqlight.Value)) {
      case data.parent_id {
        Some(parent_id) ->
          list.append(d, [#("parent_id", sqlight.int(parent_id))])
        None -> d
      }
    }
    |> map.from_list

  let #(fields, set_values) = #(map.keys(new_data), map.values(new_data))
  let #(where, where_values) = make_where_clause(condition, by)

  let query =
    "UPDATE folders SET " <> string.join(fields, with: " = ?, ") <> " = ?, updated_at = CURRENT_TIMESTAMP WHERE " <> where <> " RETURNING id, name, user_id, parent_id, UNIXEPOCH(created_at), UNIXEPOCH(updated_at);"
  logger.info(query)

  case list.length(fields) > 0 {
    True -> {
      case
        sqlight.query(
          query,
          on: db,
          with: list.append(set_values, where_values),
          expecting: folder_decoder(),
        )
      {
        Ok([row]) -> Ok(#(row, fields))
        Ok(_) -> Error(error.InternalServerError)
        Error(e) -> {
          logger.error(e.message)
          case e.code {
            sqlight.ConstraintForeignkey ->
              Error(error.ClientError("The parent folder does not exist"))
            sqlight.ConstraintUnique ->
              Error(error.ClientError("A folder with that name already exists"))
            _ -> Error(error.InternalServerError)
          }
        }
      }
    }
    False -> Error(error.CustomError("No fields to update", 400))
  }
}

pub fn as_json(folder: Folder) -> Json {
  json.object([
    #("id", json.int(folder.id)),
    #("name", json.string(folder.name)),
    #("user_id", json.int(folder.user_id)),
    #("parent_id", json.nullable(from: folder.parent_id, of: json.int)),
    #("created_at", json.int(folder.created_at)),
    #("updated_at", json.int(folder.updated_at)),
  ])
}

pub fn child_as_json(child: Child) -> Json {
  let t = case child {
    SubFolder(_) -> "folder"
    Note(_) -> "note"
  }

  let original = case child {
    SubFolder(folder) -> as_json(folder)
    Note(note) -> note.as_json(note)
  }

  json.object([#("type", json.string(t)), #("data", original)])
}
