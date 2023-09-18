import api/error
import lib/schemas/token
import lib/schemas/user.{User}
import sqlight
import ids/nanoid

pub fn generate(
  db db: sqlight.Connection,
  uid uid: Int,
) -> Result(String, error.ApiError) {
  let token = nanoid.generate()
  token.save(db, user_id: uid, token: token)
}

pub fn verify(
  db db: sqlight.Connection,
  token auth_token: String,
) -> Result(User, error.ApiError) {
  case token.find_by_value(db: db, token: auth_token) {
    Ok(tk) -> {
      case user.find_one(db: db, by: user.ID(tk.user_id)) {
        Ok(u) -> {
          let _ = token.update_last_used_at(db: db, token: auth_token)
          Ok(u)
        }
        Error(e) -> Error(e)
      }
    }
    Error(e) -> Error(e)
  }
}
