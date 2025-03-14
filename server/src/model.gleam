import gleam/option.{type Option}
import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode.{type Decoder}

pub type Context {
  Context(conn_str: String, init_secret: Option(String))
}

pub type User {
  User(id: Int, username: String, salt: String, password_hash: BitArray)
}

pub fn user_decoder() -> Decoder(User) {
  use id <- decode.field(0, decode.int)
  use username <- decode.field(1, decode.string)
  use password_hash <- decode.field(2, decode.bit_array)
  use salt <- decode.field(3, decode.string)

  decode.success(User(id:, username:, password_hash:, salt:))
}

/// Hashes a password.
pub fn hash_password(password: String, salt: String) -> BitArray {
  { password <> salt }
  |> bit_array.from_string
  |> crypto.hash(crypto.Sha512, _)
}

/// Checks the provided password against the user's password hash.
pub fn check_password(password: String, user: User) -> Bool {
  crypto.secure_compare(hash_password(password, user.salt), user.password_hash)
}
