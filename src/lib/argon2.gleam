@external(erlang, "Elixir.Argon2", "hash_pwd_salt")
pub fn hash_password(password: String) -> String

@external(erlang, "Elixir.Argon2", "verify_pass")
pub fn compare_password(password: String, hash: String) -> Bool
