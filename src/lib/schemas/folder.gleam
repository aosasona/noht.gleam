import gleam/dynamic
import sqlight

pub type Column {
  ID(Int)
  User(uid: Int)
  Parent(parent_id: Int)
}

pub type Folder {
  Folder(
    id: Int,
    name: String,
    user_id: Int,
    parent_id: Int,
    created_at: Int,
    updated_at: Int,
  )
}

fn folder_decoder() {
  dynamic.decode6(
    Folder,
    dynamic.field("id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("user_id", dynamic.int),
    dynamic.field("parent_id", dynamic.int),
    dynamic.field("created_at", dynamic.int),
    dynamic.field("updated_at", dynamic.int),
  )
}

fn get_find_params(by: Column) -> #(String, sqlight.Value) {
  case by {
    ID(id) -> #("id", sqlight.int(id))
    User(uid) -> #("user_id", sqlight.int(uid))
    Parent(parent_id) -> #("parent_id", sqlight.int(parent_id))
  }
}
