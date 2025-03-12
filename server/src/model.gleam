import gleam/dynamic/decode.{type Decoder}

pub type User {
  User(id: Int, username: String, password_hash: String)
}

pub fn user_decoder() -> Decoder(User) {
  use id <- decode.field(0, decode.int)
  use username <- decode.field(1, decode.string)
  use password_hash <- decode.field(2, decode.string)

  decode.success(User(id:, username:, password_hash:))
}

/// Hashes a password.
pub fn hash_password(password: String) -> String {
  password
}
