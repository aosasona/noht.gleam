import gleam/json.{Json}

pub type Note {
  Note(
    id: Int,
    title: String,
    body: String,
    user_id: Int,
    created_at: Int,
    updated_at: Int,
  )
}

pub fn as_json(note: Note) -> Json {
  json.object([
    #("id", json.int(note.id)),
    #("title", json.string(note.title)),
    #("body", json.string(note.body)),
    #("user_id", json.int(note.user_id)),
    #("created_at", json.int(note.created_at)),
    #("updated_at", json.int(note.updated_at)),
  ])
}
