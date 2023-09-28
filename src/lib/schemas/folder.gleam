import api/api
import api/error.{ApiError}
import lib/schemas/note.{Note}
import lib/logger
import gleam/dynamic
import gleam/option.{None, Option, Some}
import gleam/json.{Json}
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

pub type Data {
  Parent(Folder)
  Children(List(Child))
}

pub type Column {
  ID(Int)
  UserID(uid: Int)
  ParentID(parent_id: Int)
}

pub type InsertData {
  InsertData(name: String, parent_id: Option(Int), user_id: Int)
}

fn folder_decoder() {
  dynamic.decode6(
    Folder,
    dynamic.field("id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("user_id", dynamic.int),
    dynamic.field("parent_id", dynamic.optional(dynamic.int)),
    dynamic.field("created_at", dynamic.int),
    dynamic.field("updated_at", dynamic.int),
  )
}

fn get_find_params(by: Column) -> #(String, sqlight.Value) {
  case by {
    ID(id) -> #("id", sqlight.int(id))
    UserID(uid) -> #("user_id", sqlight.int(uid))
    ParentID(parent_id) -> #("parent_id", sqlight.int(parent_id))
  }
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
      Error(error.InternalServerError)
    }
  }
}

pub fn as_json(data: Data) -> Json {
  case data {
    Parent(folder) -> folder_as_json(folder)
    Children(children) -> json.array(from: children, of: child_as_json)
  }
}

fn folder_as_json(folder: Folder) -> Json {
  json.object([
    #("id", json.int(folder.id)),
    #("name", json.string(folder.name)),
    #("user_id", json.int(folder.user_id)),
    #("parent_id", json.nullable(from: folder.parent_id, of: json.int)),
    #("created_at", json.int(folder.created_at)),
    #("updated_at", json.int(folder.updated_at)),
  ])
}

fn child_as_json(child: Child) -> Json {
  case child {
    SubFolder(folder) -> folder_as_json(folder)
    Note(note) -> note.as_json(note)
  }
}
